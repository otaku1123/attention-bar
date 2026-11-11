import Foundation
import Testing
@testable import AttentionBar

struct MeetingURLTests {
    @Test(arguments: [
        "https://meet.google.com/abc-defg-hij",
        "https://us02web.zoom.us/j/1234567890",
        "https://company.zoomgov.com/j/1234567890",
        "https://teams.microsoft.com/l/meetup-join/xyz",
        "https://teams.live.com/meet/123",
        "https://teams.cloud.microsoft/l/meetup-join/xyz",
        "https://company.webex.com/meet/someone",
        "https://app.slack.com/huddle/T0123/C0456",
        "https://chime.aws/1234567890",
        "https://whereby.com/team-room",
        "https://meet.jit.si/MyRoom",
        "https://meet.goto.com/123456789",
        "https://global.gotomeeting.com/join/123456789",
        "https://join.skype.com/abcdef",
        "https://meeting.zoho.com/meeting/join?key=123",
        "https://v.ringcentral.com/join/123456",
    ])
    func detectsMeetingURL(url: String) {
        #expect(CalendarProvider.meetingURL(in: "参加: \(url)")?.absoluteString == url)
    }

    @Test(arguments: [
        // 資料・メッセージのリンクは会議として拾わない
        "https://docs.google.com/document/d/abc",
        "https://app.slack.com/client/T0123/C0456",
        "https://example.com/zoom.us",
        "https://notzoom.us/j/123",
    ])
    func ignoresOtherURL(url: String) {
        #expect(CalendarProvider.meetingURL(in: "資料: \(url)") == nil)
    }

    @Test func returnsFirstMeetingURLAfterOtherLinks() {
        let text = """
            資料: https://docs.google.com/document/d/abc
            Zoom: https://zoom.us/j/111
            予備: https://meet.google.com/xyz-abcd-efg
            """
        #expect(CalendarProvider.meetingURL(in: text)?.absoluteString == "https://zoom.us/j/111")
    }

    @Test func returnsNilForEmptyText() {
        #expect(CalendarProvider.meetingURL(in: "") == nil)
    }
}

struct CalendarAppURLTests {
    @Test func singleEvent() {
        let url = CalendarProvider.calendarAppURL(identifier: "ABC-123", occurrence: nil)
        #expect(url?.absoluteString == "ical://ekevent/ABC-123?method=show&options=more")
    }

    @Test func recurringEventIncludesOccurrenceInUTC() {
        // 2027-01-15 08:00:00 UTC
        let url = CalendarProvider.calendarAppURL(identifier: "ABC-123", occurrence: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(url?.absoluteString == "ical://ekevent/20270115T080000Z/ABC-123?method=show&options=more")
    }

    @Test func escapesIdentifier() {
        let url = CalendarProvider.calendarAppURL(identifier: "a/b:c", occurrence: nil)
        #expect(url?.absoluteString == "ical://ekevent/a%2Fb:c?method=show&options=more")
    }
}
