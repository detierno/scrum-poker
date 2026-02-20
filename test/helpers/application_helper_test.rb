# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "shareable_room_url returns full URL with join path and code" do
    url = shareable_room_url("ABC123")

    assert_match %r{\Ahttps?://}, url
    assert_match %r{/rooms/join\?code=ABC123\z}, url
    assert_includes url, "ABC123"
  end

  test "shareable_room_url includes path and code" do
    url = shareable_room_url("XYZ789")

    assert_includes url, "rooms/join"
    assert_includes url, "code=XYZ789"
    assert_match %r{/rooms/join\?code=XYZ789}, url
  end
end
