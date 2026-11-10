package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/mmdshin/ava/server/internal/api"
	"github.com/mmdshin/ava/server/internal/auth"
	"github.com/mmdshin/ava/server/internal/content"
	"github.com/mmdshin/ava/server/internal/contentfile"
	"github.com/mmdshin/ava/server/internal/store"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	cmd, args := os.Args[1], os.Args[2:]
	var err error
	switch cmd {
	case "migrate":
		err = withStore(ctx, func(s *store.Store) error { return migrate(ctx, s) })
	case "import":
		err = importCmd(ctx, args)
	case "validate":
		err = withStore(ctx, func(s *store.Store) error { return validate(ctx, s) })
	case "publish":
		err = publishCmd(ctx, args)
	case "versions":
		err = withStore(ctx, func(s *store.Store) error { return versions(ctx, s) })
	case "create-user":
		err = createUser(ctx, args)
	case "set-role":
		err = setRole(ctx, args)
	case "serve":
		err = serve(ctx, log)
	case "help", "-h", "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", cmd)
		usage()
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `usage: ava-server <command> [flags]

commands:
  migrate     create or upgrade the database tables
  import      load content JSON files into the database (--dir, --replace)
  validate    check the current draft content
  publish     publish the draft as a new version (--notes, --by)
  versions    list published versions
  create-user create an account (--email, --role, --name; password from AVA_PASSWORD or stdin)
  set-role    change an account's role (--email, --role)
  serve       run the HTTP API (env ADDR, CORS_ORIGINS, ALLOW_SIGNUP)

environment: DATABASE_URL (required)
`)
}

func withStore(ctx context.Context, fn func(*store.Store) error) error {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return errors.New("DATABASE_URL is not set")
	}
	s, err := store.Open(ctx, url)
	if err != nil {
		return err
	}
	defer s.Close()
	return fn(s)
}

func migrate(ctx context.Context, s *store.Store) error {
	applied, err := s.Migrate(ctx)
	for _, name := range applied {
		fmt.Println("applied", name)
	}
	if err == nil && len(applied) == 0 {
		fmt.Println("database is up to date")
	}
	return err
}

func importCmd(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("import", flag.ExitOnError)
	dir := fs.String("dir", "", "folder with care_plans.json, quizzes.json and gordon_domains.json")
	file := fs.String("file", "", "one bundle JSON file (as served by /v1/content/bundle)")
	replace := fs.Bool("replace", false, "delete existing (unpublished) content first")
	fs.Parse(args)

	var b *content.Bundle
	var err error
	switch {
	case *file != "":
		b, err = contentfile.ReadBundle(*file)
	case *dir != "":
		b, err = contentfile.Read(*dir)
	default:
		return errors.New("give --file bundle.json or --dir folder")
	}
	if err != nil {
		return err
	}
	issues := content.Validate(b)
	printIssues(issues)
	if !issues.OK() {
		return errors.New("fix the errors above before importing")
	}
	return withStore(ctx, func(s *store.Store) error {
		if _, err := s.Migrate(ctx); err != nil {
			return err
		}
		if err := s.Import(ctx, b, *replace); err != nil {
			return err
		}
		fmt.Printf("imported %d care plans, %d quizzes, %d Gordon domains\n",
			len(b.CarePlans), len(b.Quizzes), len(b.GordonDomains))
		fmt.Println("next: ava-server publish --notes \"first version\"")
		return nil
	})
}

func validate(ctx context.Context, s *store.Store) error {
	draft, err := s.Draft(ctx)
	if err != nil {
		return err
	}
	issues := content.Validate(draft)
	printIssues(issues)
	if !issues.OK() {
		return errors.New("the draft can't be published yet")
	}
	fmt.Println("the draft is valid")
	return nil
}

func publishCmd(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("publish", flag.ExitOnError)
	notes := fs.String("notes", "", "what changed (shown in the version history)")
	by := fs.String("by", os.Getenv("USER"), "who is publishing")
	ignoreFreeze := fs.Bool("ignore-freeze", false, "publish even though publishing is frozen")
	fs.Parse(args)

	return withStore(ctx, func(s *store.Store) error {
		v, issues, err := s.Publish(ctx, store.PublishRequest{
			Notes:        *notes,
			By:           store.Actor{Email: "cli:" + *by},
			IgnoreFreeze: *ignoreFreeze,
		})
		if errors.Is(err, store.ErrFrozen) {
			f, _ := s.Freeze(ctx)
			return fmt.Errorf("publishing is frozen (%s); use --ignore-freeze only if this change is approved", f.Reason)
		}
		printIssues(issues)
		if errors.Is(err, store.ErrNothingChanged) {
			fmt.Println(err)
			return nil
		}
		if err != nil {
			return err
		}
		fmt.Printf("published version %d (%d KB)\n", v.Version, len(v.Bundle)/1024)
		return nil
	})
}

func versions(ctx context.Context, s *store.Store) error {
	vs, err := s.Versions(ctx)
	if err != nil {
		return err
	}
	if len(vs) == 0 {
		fmt.Println("nothing published yet")
	}
	for _, v := range vs {
		fmt.Printf("v%-4d %s  %-12s %s\n", v.Version,
			v.PublishedAt.Local().Format("2006-01-02 15:04"), v.PublishedBy, v.Notes)
	}
	return nil
}

func printIssues(is content.Issues) {
	for _, e := range is.Errors {
		fmt.Println("  error:  ", e)
	}
	for _, w := range is.Warnings {
		fmt.Println("  warning:", w)
	}
}

func serve(ctx context.Context, log *slog.Logger) error {
	return withStore(ctx, func(s *store.Store) error {
		if _, err := s.Migrate(ctx); err != nil {
			return err
		}
		addr := envOr("ADDR", ":8080")
		go cleanSessions(ctx, s, log)
		origins := strings.Split(envOr("CORS_ORIGINS", "*"), ",")
		for i := range origins {
			origins[i] = strings.TrimSpace(origins[i])
		}
		srv := &http.Server{
			Addr: addr,
			Handler: (&api.Server{
				Store:          s,
				Log:            log,
				AllowedOrigins: origins,
				CacheTTL:       30 * time.Second,
				AllowSignup:    envOr("ALLOW_SIGNUP", "true") != "false",
			}).Handler(),
			ReadHeaderTimeout: 10 * time.Second,
			ReadTimeout:       30 * time.Second,
			WriteTimeout:      60 * time.Second,
			IdleTimeout:       120 * time.Second,
		}
		errc := make(chan error, 1)
		go func() {
			log.Info("listening", "addr", addr)
			errc <- srv.ListenAndServe()
		}()
		select {
		case err := <-errc:
			return err
		case <-ctx.Done():
			log.Info("shutting down")
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			return srv.Shutdown(shutdownCtx)
		}
	})
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// cleanSessions deletes expired sessions every few hours.
func cleanSessions(ctx context.Context, s *store.Store, log *slog.Logger) {
	t := time.NewTicker(6 * time.Hour)
	defer t.Stop()
	for {
		if n, err := s.DeleteExpiredSessions(ctx); err != nil && ctx.Err() == nil {
			log.Error("cleaning sessions", "err", err)
		} else if n > 0 {
			log.Info("deleted expired sessions", "count", n)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func createUser(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("create-user", flag.ExitOnError)
	email := fs.String("email", "", "email address")
	name := fs.String("name", "", "display name")
	role := fs.String("role", store.RoleNurse, "nurse, editor, reviewer or admin")
	fs.Parse(args)
	if *email == "" {
		return errors.New("--email is required")
	}
	password := os.Getenv("AVA_PASSWORD")
	if password == "" {
		fmt.Fprint(os.Stderr, "password: ")
		line, err := bufio.NewReader(os.Stdin).ReadString('\n')
		if err != nil && line == "" {
			return err
		}
		password = strings.TrimRight(line, "\r\n")
	}
	if err := auth.CheckPasswordPolicy(password); err != nil {
		return err
	}
	hash, err := auth.HashPassword(password)
	if err != nil {
		return err
	}
	return withStore(ctx, func(s *store.Store) error {
		if _, err := s.Migrate(ctx); err != nil {
			return err
		}
		u, err := s.CreateUser(ctx, *email, *name, hash, *role)
		if err != nil {
			return err
		}
		fmt.Printf("created %s (%s)\n", u.Email, u.Role)
		return nil
	})
}

func setRole(ctx context.Context, args []string) error {
	fs := flag.NewFlagSet("set-role", flag.ExitOnError)
	email := fs.String("email", "", "email address")
	role := fs.String("role", "", "nurse, editor, reviewer or admin")
	fs.Parse(args)
	return withStore(ctx, func(s *store.Store) error {
		if err := s.SetRole(ctx, *email, *role); err != nil {
			return err
		}
		fmt.Printf("%s is now %s\n", *email, *role)
		return nil
	})
}
