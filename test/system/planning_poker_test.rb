# frozen_string_literal: true

require "application_system_test_case"

class PlanningPokerTest < ApplicationSystemTestCase
  setup do
    RoomStore.reset!
  end

  test "user can create a room" do
    visit root_path

    assert_selector "h1", text: "Planning Poker"
    fill_in "name", with: "Alice"
    click_button "Create room"

    assert_current_path %r{/rooms/[A-Z]{6}}
    assert_text "Room created!"
    assert_text "You're playing as Alice"
    assert_selector ".room__code"
  end

  test "user can join a room by code" do
    # Create room as admin
    admin_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = admin_result[:room].code

    visit root_path
    fill_in "code", with: room_code
    click_button "Join"

    assert_match %r{/rooms/join}, current_path
    assert_field "code", with: room_code
    fill_in "name", with: "Bob"
    click_button "Join room"

    assert_current_path "/rooms/#{room_code}"
    assert_text "Joined the room!"
    assert_text "You're playing as Bob"
  end

  test "user can join a room via direct link" do
    admin_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = admin_result[:room].code

    visit room_path(room_code)

    assert_match %r{/rooms/join}, current_path
    assert_field "code", with: room_code
    fill_in "name", with: "Charlie"
    click_button "Join room"

    assert_current_path "/rooms/#{room_code}"
    assert_text "You're playing as Charlie"
  end

  test "user sees error when joining invalid room" do
    visit root_path
    fill_in "code", with: "INVALID"
    click_button "Join"

    assert_match %r{/rooms/join}, current_path
    fill_in "name", with: "Bob"
    click_button "Join room"

    assert_current_path root_path
    assert_text "Room not found"
  end

  test "room page displays correctly after creation" do
    visit root_path
    fill_in "name", with: "Admin"
    click_button "Create room"

    assert_selector ".room__header"
    assert_selector ".room__code"
    assert_selector ".room__share"
    assert_selector ".participants"
    assert_selector ".voting"
    assert_text "Admin"
  end

  test "room shows shareable link in join URL format" do
    visit root_path
    fill_in "name", with: "Admin"
    click_button "Create room"

    share_input = find("input[readonly]")
    assert share_input.value.present?
    assert_match %r{/rooms/join\?code=[A-Z]{6}}, share_input.value, "Share link should be join URL with room code"
  end

  test "Copy button is present on room page" do
    visit root_path
    fill_in "name", with: "Admin"
    click_button "Create room"

    copy_btn = find("button", text: "Copy")
    assert copy_btn
  end

  test "participants list shows all participants" do
    admin_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = admin_result[:room].code

    # Join as Bob
    visit root_path
    fill_in "code", with: room_code
    click_button "Join"
    fill_in "name", with: "Bob"
    click_button "Join room"

    assert_text "Admin"
    assert_text "Bob"
  end

  test "voting cards show fibonacci points" do
    visit root_path
    fill_in "name", with: "Admin"
    click_button "Create room"

    RoomStore::Room::FIBONACCI_POINTS.each do |point|
      assert_text point.to_s
    end
  end

  test "home page shows create and join forms" do
    visit root_path

    assert_selector "h1", text: "Planning Poker"
    assert_field "name"
    assert_button "Create room"
    assert_field "code"
    assert_button "Join"
  end

  test "join form requires code" do
    visit join_room_path

    assert_current_path root_path
  end

  test "join form pre-fills code from query parameter" do
    admin_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = admin_result[:room].code

    visit join_room_path(code: room_code)

    assert_field "code", with: room_code
  end
end
