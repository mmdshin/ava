package content

// SchemaVersion is the shape of the JSON below. Bump it only for changes
// an older app can't read; the app ignores bundles with a newer schema.
//
//	1  the first shape (diseases fixed in the app)
//	2  "categories": the diseases are content
const SchemaVersion = 2

// GeneralCategory holds the plans that apply to every disease. It
// always exists; the diagnosis finder shows its plans for any disease.
const GeneralCategory = "general"

// CategoryIcons are the icon names the app can show for a category
// (Material icon names; keep in sync with the app's lib/core/kind_style.dart).
var CategoryIcons = []string{
	"monitor_heart", "favorite", "bloodtype", "emergency", "health_and_safety",
	"medical_information", "local_hospital", "air", "psychology", "water_drop",
	"medication", "vaccines", "healing", "coronavirus", "sick", "masks",
	"child_care", "pregnant_woman", "elderly", "accessible", "visibility", "science",
}

// DefaultCategories are the five diseases the app started with. Used
// when importing content files that don't list categories.
func DefaultCategories() []Category {
	return []Category{
		{ID: "acs", Title: "سندرم کرونری حاد", Abbr: "ACS", Color: "#17A398", Icon: "monitor_heart"},
		{ID: "chf", Title: "نارسایی قلبی", Abbr: "CHF", Color: "#3D8BFF", Icon: "favorite"},
		{ID: "dvt", Title: "ترومبوز ورید عمقی", Abbr: "DVT", Color: "#8B5CF6", Icon: "bloodtype"},
		{ID: "mi", Title: "انفارکتوس میوکارد", Abbr: "MI", Color: "#F2A93E", Icon: "emergency"},
		{ID: GeneralCategory, Title: "عمومی", Color: "#EF5875", Icon: "health_and_safety"},
	}
}

// SectionTypes are the fixed NANDA-I section types of a care plan.
var SectionTypes = []string{
	"definition", "relatedTo", "definingCharacteristics",
	"riskFactors", "interventions", "outcomes",
}

// Bundle is everything the app downloads in one go.
type Bundle struct {
	SchemaVersion int    `json:"schemaVersion"`
	Version       int    `json:"version"`
	PublishedAt   string `json:"publishedAt,omitempty"`
	// In display order.
	Categories    []Category `json:"categories"`
	CarePlans     []CarePlan `json:"carePlans"`
	Quizzes       []Quiz     `json:"quizzes"`
	GordonDomains []Domain   `json:"gordonDomains"`
}

// Category is a disease (or "general") that care plans and quizzes
// belong to.
type Category struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	// Short code for cards ("ACS"); empty for none.
	Abbr  string `json:"abbr,omitempty"`
	Color string `json:"color"` // "#RRGGBB"
	Icon  string `json:"icon"`
}

type CarePlan struct {
	ID       string    `json:"id"`
	Kind     string    `json:"kind"`
	Title    string    `json:"title"`
	Tags     []string  `json:"tags"`
	Sections []Section `json:"sections"`
}

type Section struct {
	Type  string   `json:"type"`
	Title string   `json:"title,omitempty"`
	Items []string `json:"items"`
}

type Quiz struct {
	ID        string     `json:"id"`
	Title     string     `json:"title"`
	Kind      string     `json:"kind,omitempty"`
	Questions []Question `json:"questions"`
}

type Question struct {
	ID           string   `json:"id"`
	Text         string   `json:"text"`
	Options      []string `json:"options"`
	CorrectIndex int      `json:"correctIndex"`
	Explanation  string   `json:"explanation,omitempty"`
	Hint         string   `json:"hint,omitempty"`
}

type Domain struct {
	ID    string    `json:"id"`
	Title string    `json:"title"`
	Order int       `json:"order"`
	Items []Finding `json:"items"`
}

type Finding struct {
	ID    string   `json:"id"`
	Title string   `json:"title"`
	Tags  []string `json:"tags"`
}
