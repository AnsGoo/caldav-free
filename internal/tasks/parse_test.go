package tasks

import (
	"testing"
	"time"
)

func mustLoc(t *testing.T) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		t.Fatal(err)
	}
	return loc
}

func TestParseQuickAdd(t *testing.T) {
	loc := mustLoc(t)
	now := time.Date(2026, 10, 22, 9, 30, 0, 0, loc) // Thursday

	cases := []struct {
		in       string
		title    string
		priority int
		tags     []string
		due      string
		allDay   bool
	}{
		{
			in:       "明天下午3点和张三开会 #工作 !!",
			title:    "和张三开会",
			priority: 2,
			tags:     []string{"工作"},
			due:      "2026-10-23T15:00:00+08:00",
		},
		{
			in:    "下周一 10点 提交周报",
			title: "提交周报",
			due:   "2026-10-26T10:00:00+08:00",
		},
		{
			in:     "写周报 周五",
			title:  "写周报",
			due:    "2026-10-23T00:00:00+08:00",
			allDay: true,
		},
		{
			in:     "10月25日 买生日礼物",
			title:  "买生日礼物",
			due:    "2026-10-25T00:00:00+08:00",
			allDay: true,
		},
		{
			in:    "15:30 打电话",
			title: "打电话",
			due:   "2026-10-22T15:30:00+08:00",
		},
		{
			in:    "3点 起床",
			title: "起床",
			due:   "2026-10-22T15:00:00+08:00",
		},
		{
			in:    "今晚 8点 跑步 #健康",
			title: "跑步",
			tags:  []string{"健康"},
			due:   "2026-10-22T20:00:00+08:00",
		},
	}

	for _, tc := range cases {
		got := Parse(tc.in, now, loc)
		if got.Title != tc.title {
			t.Errorf("%q: title = %q, want %q", tc.in, got.Title, tc.title)
		}
		if got.Priority != tc.priority {
			t.Errorf("%q: priority = %d, want %d", tc.in, got.Priority, tc.priority)
		}
		if len(got.Tags) != len(tc.tags) {
			t.Errorf("%q: tags = %v, want %v", tc.in, got.Tags, tc.tags)
		} else {
			for i := range tc.tags {
				if got.Tags[i] != tc.tags[i] {
					t.Errorf("%q: tags = %v, want %v", tc.in, got.Tags, tc.tags)
					break
				}
			}
		}
		if tc.due == "" {
			if got.Due != nil {
				t.Errorf("%q: due = %v, want nil", tc.in, got.Due)
			}
			continue
		}
		want, err := time.Parse(time.RFC3339, tc.due)
		if err != nil {
			t.Fatal(err)
		}
		if got.Due == nil || !got.Due.Equal(want) {
			t.Errorf("%q: due = %v, want %v", tc.in, got.Due, want)
		}
		if got.AllDay != tc.allDay {
			t.Errorf("%q: allDay = %v, want %v", tc.in, got.AllDay, tc.allDay)
		}
	}
}

func TestParseWeekdayMonday(t *testing.T) {
	loc := mustLoc(t)
	monday := time.Date(2026, 10, 26, 0, 0, 0, 0, loc)
	for _, in := range []string{"周一 复盘", "本周一 复盘"} {
		got := Parse(in, time.Date(2026, 10, 26, 9, 0, 0, 0, loc), loc)
		if got.Title != "复盘" {
			t.Fatalf("%q: title = %q", in, got.Title)
		}
		if got.Due == nil || !got.Due.Equal(monday) {
			t.Fatalf("%q: due = %v, want %v", in, got.Due, monday)
		}
	}
	got := Parse("下周一 复盘", time.Date(2026, 10, 26, 9, 0, 0, 0, loc), loc)
	next := time.Date(2026, 11, 2, 0, 0, 0, 0, loc)
	if got.Due == nil || !got.Due.Equal(next) {
		t.Fatalf("下周一: due = %v, want %v", got.Due, next)
	}
}

func TestParseThisWeekUsesMondayOfCurrentWeek(t *testing.T) {
	loc := mustLoc(t)
	now := time.Date(2026, 10, 22, 9, 30, 0, 0, loc) // Thursday
	got := Parse("本周一 复盘", now, loc)
	want := time.Date(2026, 10, 19, 0, 0, 0, 0, loc)
	if got.Due == nil || !got.Due.Equal(want) {
		t.Fatalf("due = %v, want %v", got.Due, want)
	}
}

func TestParsePastDateRollsForward(t *testing.T) {
	loc := mustLoc(t)
	now := time.Date(2026, 10, 22, 9, 30, 0, 0, loc)
	got := Parse("1月5日 交年报", now, loc)
	want := time.Date(2027, 1, 5, 0, 0, 0, 0, loc)
	if got.Due == nil || !got.Due.Equal(want) {
		t.Fatalf("due = %v, want %v", got.Due, want)
	}
}
