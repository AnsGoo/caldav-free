package web

import (
	"container/list"
	"net/http"
	"time"

	lunarcalendar "github.com/6tail/lunar-go/calendar"

	"caldav-free/internal/store"
)

type apiAlmanacDay struct {
	Date     string `json:"date"`
	Lunar    string `json:"lunar"`
	JieQi    string `json:"jieQi"`
	Festival string `json:"festival"`
	Label    string `json:"label"`
}

// apiCalendarAlmanac returns the cultural label shown under a month-grid date:
// lunar day, solar term or traditional festival. The range is bounded by the
// same 120-day limit as the calendar endpoint.
func (s *Server) apiCalendarAlmanac(w http.ResponseWriter, r *http.Request, _ *store.User) {
	from, to, ok := parseEventRange(r)
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "时间范围无效")
		return
	}
	loc := taskLocation("")
	start := time.Date(from.In(loc).Year(), from.In(loc).Month(), from.In(loc).Day(), 0, 0, 0, 0, loc)
	end := to.In(loc)
	days := make([]apiAlmanacDay, 0, 42)
	for day := start; day.Before(end); day = day.AddDate(0, 0, 1) {
		solar := lunarcalendar.NewSolarFromDate(day)
		lunar := solar.GetLunar()
		lunarLabel := lunar.GetDayInChinese()
		if lunarLabel == "初一" {
			lunarLabel = lunar.GetMonthInChinese() + "月"
		}
		jieQi := lunar.GetJieQi()
		festival := firstFestival(solar.GetFestivals())
		if festival == "" {
			festival = firstFestival(lunar.GetFestivals())
		}
		label := lunarLabel
		if jieQi != "" {
			label = jieQi
		}
		if festival != "" {
			label = festival
		}
		days = append(days, apiAlmanacDay{
			Date:     day.Format("2006-01-02"),
			Lunar:    lunarLabel,
			JieQi:    jieQi,
			Festival: festival,
			Label:    label,
		})
	}
	writeAPIJSON(w, http.StatusOK, map[string]any{"days": days})
}

func firstFestival(values *list.List) string {
	if values == nil {
		return ""
	}
	for item := values.Front(); item != nil; item = item.Next() {
		value, ok := item.Value.(string)
		if ok && value != "" {
			return value
		}
	}
	return ""
}
