// Package tasks implements natural-language parsing for the quick-add box.
package tasks

import (
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode"
)

// Result is the structured interpretation of a quick-add line.
type Result struct {
	Title    string
	Due      *time.Time
	AllDay   bool
	Priority int
	Tags     []string
}

var (
	reTag      = regexp.MustCompile(`#([\p{L}\p{N}_\-]+)`)
	rePriority = regexp.MustCompile(`[!！]{1,3}`)
	reYMD      = regexp.MustCompile(`(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*[日号]?`)
	reMD       = regexp.MustCompile(`(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?`)
	reWeekday  = regexp.MustCompile(`(下|本|这)?\s*(?:周|星期|礼拜)\s*([一二三四五六日天])`)
	reDaysFrom = regexp.MustCompile(`(\d{1,2})\s*天\s*(?:之)?后`)
	reClock    = regexp.MustCompile(`(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上)?\s*(\d{1,2})\s*(?:点|时)\s*(半|\d{1,2}\s*分?)?`)
	reHM       = regexp.MustCompile(`(凌晨|早上|早晨|上午|中午|下午|傍晚|晚上)?\s*(\d{1,2})\s*[:：]\s*(\d{1,2})`)
)

// Parse extracts a due date, priority and tags from a quick-add line. Date
// words are removed from the returned title. Parsing is intentionally
// conservative: when no time is present the task is an all-day task.
func Parse(input string, now time.Time, loc *time.Location) Result {
	if loc == nil {
		loc = time.Local
	}
	now = now.In(loc)
	result := Result{}
	work := strings.TrimSpace(input)
	evening := strings.Contains(input, "今晚") || strings.Contains(input, "明晚")

	// Tags: #work #家庭
	work = reTag.ReplaceAllStringFunc(work, func(match string) string {
		tag := strings.TrimSpace(match[1:])
		if tag != "" {
			result.Tags = append(result.Tags, tag)
		}
		return " "
	})

	// Priority: ! to !!!
	work = rePriority.ReplaceAllStringFunc(work, func(match string) string {
		level := len([]rune(match))
		if level > 3 {
			level = 3
		}
		if level > result.Priority {
			result.Priority = level
		}
		return " "
	})

	year, month, day := 0, 0, 0
	hasDate := false
	fromMonthDay := false

	replaceDate := func(re *regexp.Regexp, fn func([]string) (int, int, int, bool)) {
		if hasDate {
			return
		}
		if m := re.FindStringSubmatch(work); m != nil {
			y, mo, d, ok := fn(m)
			if ok {
				year, month, day = y, mo, d
				hasDate = true
				work = strings.Replace(work, m[0], " ", 1)
			}
		}
	}

	replaceDate(reYMD, func(m []string) (int, int, int, bool) {
		y, _ := strconv.Atoi(m[1])
		mo, _ := strconv.Atoi(m[2])
		d, _ := strconv.Atoi(m[3])
		if mo < 1 || mo > 12 || d < 1 || d > 31 {
			return 0, 0, 0, false
		}
		return y, mo, d, true
	})
	replaceDate(reMD, func(m []string) (int, int, int, bool) {
		mo, _ := strconv.Atoi(m[1])
		d, _ := strconv.Atoi(m[2])
		if mo < 1 || mo > 12 || d < 1 || d > 31 {
			return 0, 0, 0, false
		}
		fromMonthDay = true
		return now.Year(), mo, d, true
	})

	// Relative days.
	if !hasDate {
		for _, item := range []struct {
			word string
			days int
		}{
			{"大后天", 3}, {"后天", 2}, {"明天", 1}, {"明日", 1}, {"明晚", 1},
			{"今晚", 0}, {"今天", 0}, {"今日", 0},
		} {
			if strings.Contains(work, item.word) {
				target := now.AddDate(0, 0, item.days)
				year, month, day = target.Year(), int(target.Month()), target.Day()
				hasDate = true
				work = strings.Replace(work, item.word, " ", 1)
				if item.word == "今晚" || item.word == "明晚" {
					// Evening shorthand: 20:00 on that day.
					if result.Due == nil {
						d := time.Date(year, time.Month(month), day, 20, 0, 0, 0, loc)
						result.Due = &d
					}
				}
				break
			}
		}
	}

	// "N天后".
	if !hasDate {
		if m := reDaysFrom.FindStringSubmatch(work); m != nil {
			if n, err := strconv.Atoi(m[1]); err == nil && n >= 0 && n < 3660 {
				target := now.AddDate(0, 0, n)
				year, month, day = target.Year(), int(target.Month()), target.Day()
				hasDate = true
				work = strings.Replace(work, m[0], " ", 1)
			}
		}
	}

	// Weekdays: 周三, 下周一, 星期日.
	if !hasDate {
		if m := reWeekday.FindStringSubmatch(work); m != nil {
			prefix, name := m[1], m[2]
			target := weekdayNumber(name)
			if target >= 0 {
				today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
				delta := (target - int(today.Weekday()) + 7) % 7
				switch prefix {
				case "下":
					daysToMonday := (8 - int(today.Weekday())) % 7
					if daysToMonday == 0 {
						daysToMonday = 7
					}
					monday := today.AddDate(0, 0, daysToMonday)
					targetDate := monday.AddDate(0, 0, (target+6)%7)
					year, month, day = targetDate.Year(), int(targetDate.Month()), targetDate.Day()
				case "本", "这":
					// "本周一" is the Monday of the current week even when it
					// already passed (unlike a bare "周一", which looks ahead).
					monday := today.AddDate(0, 0, -((int(today.Weekday()) + 6) % 7))
					targetDate := monday.AddDate(0, 0, (target+6)%7)
					year, month, day = targetDate.Year(), int(targetDate.Month()), targetDate.Day()
				default:
					targetDate := today.AddDate(0, 0, delta)
					year, month, day = targetDate.Year(), int(targetDate.Month()), targetDate.Day()
				}
				hasDate = true
				work = strings.Replace(work, m[0], " ", 1)
			}
		}
	}

	// Time of day.
	hour, minute := -1, 0
	if m := reClock.FindStringSubmatch(work); m != nil {
		period := m[1]
		h, errH := strconv.Atoi(m[2])
		minText := strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(m[3]), "分"))
		min := 0
		if minText == "半" {
			min = 30
		} else if minText != "" {
			if n, err := strconv.Atoi(minText); err == nil {
				min = n
			}
		}
		if errH == nil && h >= 0 && h <= 24 && min >= 0 && min < 60 {
			if period == "" && evening {
				period = "晚上"
			}
			hour = convertHour(h, period)
			if hour == 24 {
				hour = 0
			}
			minute = min
			work = strings.Replace(work, m[0], " ", 1)
		}
	}
	if hour < 0 {
		if m := reHM.FindStringSubmatch(work); m != nil {
			h, errH := strconv.Atoi(m[2])
			min, errM := strconv.Atoi(m[3])
			if errH == nil && errM == nil && h >= 0 && h < 24 && min >= 0 && min < 60 {
				period := m[1]
				if period == "" && evening {
					period = "晚上"
				}
				hour, minute = convertHour(h, period), min
				work = strings.Replace(work, m[0], " ", 1)
			}
		}
	}

	if hasDate {
		target := time.Date(year, time.Month(month), day, 0, 0, 0, 0, loc)
		if fromMonthDay && target.Before(time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)) {
			// A bare month/day that already passed refers to next year.
			target = target.AddDate(1, 0, 0)
		}
		if hour >= 0 {
			target = time.Date(target.Year(), target.Month(), target.Day(), hour, minute, 0, 0, loc)
			result.AllDay = false
		} else if result.Due != nil {
			// 今晚/明晚 already supplied an evening time.
			target = *result.Due
			result.AllDay = false
		} else {
			result.AllDay = true
		}
		result.Due = &target
	} else if hour >= 0 {
		target := time.Date(now.Year(), now.Month(), now.Day(), hour, minute, 0, 0, loc)
		result.Due = &target
		result.AllDay = false
	}

	result.Title = cleanTitle(work)
	return result
}

func convertHour(h int, period string) int {
	switch period {
	case "凌晨":
		if h == 12 {
			return 0
		}
		return h
	case "早上", "早晨", "上午":
		if h == 12 {
			return 0
		}
		return h
	case "中午":
		if h < 11 {
			return 12
		}
		return h
	case "下午", "傍晚", "晚上":
		if h < 12 {
			return h + 12
		}
		return h
	default:
		// Bare "3点" is far more likely to mean 15:00 for a task.
		if h >= 1 && h <= 6 {
			return h + 12
		}
		return h
	}
}

func weekdayNumber(name string) int {
	switch name {
	case "一":
		return 1
	case "二":
		return 2
	case "三":
		return 3
	case "四":
		return 4
	case "五":
		return 5
	case "六":
		return 6
	case "日", "天":
		return 0
	}
	return -1
}

func cleanTitle(value string) string {
	value = strings.Join(strings.Fields(value), " ")
	value = strings.TrimFunc(value, func(r rune) bool {
		return unicode.IsSpace(r) || strings.ContainsRune(",，。;；:：-—~～", r)
	})
	return value
}
