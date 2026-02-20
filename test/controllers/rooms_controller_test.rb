# frozen_string_literal: true

require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    RoomStore.reset!
  end

  test "GET root shows home page" do
    get root_path
    assert_response :success
    assert_select "h1", "Planning Poker"
    assert_select "form[action=?]", rooms_path
  end

  test "POST create creates room and redirects" do
    post rooms_path, params: { name: "Alice" }

    assert_response :redirect
    assert_match %r{/rooms/[A-Z]{6}}, @response.redirect_url
    assert_equal "Alice", session[:participant_name]
    assert session[:room_admin]
  end

  test "GET show requires session" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    get room_path(room_code)

    assert_redirected_to join_room_path(code: room_code)
  end

  test "GET show with session displays room" do
    post rooms_path, params: { name: "Admin" }
    assert_redirected_to %r{/rooms/([A-Z]{6})}
    room_code = session[:room_code]

    get room_path(room_code)
    assert_response :success
    assert_select ".room__code", text: /Room: \w+/
  end

  test "GET join_form with code shows form" do
    get join_room_path, params: { code: "ABC123" }
    assert_response :success
    assert_select "form" do
      assert_select "input[name=code][value=ABC123]"
    end
  end

  test "GET join_form without code redirects to root" do
    get join_room_path
    assert_redirected_to root_path
  end

  test "POST join adds participant and redirects" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    post join_room_with_code_path(room_code), params: { code: room_code, name: "Bob" }

    assert_redirected_to room_path(room_code)
    assert_equal "Bob", session[:participant_name]
    assert_equal room_code, session[:room_code]
  end

  test "POST join with invalid code redirects with alert" do
    post join_room_with_code_path("INVALID"), params: { code: "INVALID", name: "Bob" }

    assert_redirected_to root_path
    assert_equal "Room not found. Please check the code and try again.", flash[:alert]
  end

  test "POST create without name raises parameter missing" do
    post rooms_path, params: {}
    assert_response :bad_request
  end

  test "POST join without name raises parameter missing" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    post join_room_with_code_path(room_code), params: { code: room_code }
    assert_response :bad_request
  end

  test "POST join without name parameter" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    # Code comes from URL path, so only name is required in params
    post join_room_with_code_path(room_code), params: {}
    assert_response :bad_request
  end

  test "GET show redirects to join form when no session and code in URL" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    get room_path(room_code)

    assert_redirected_to join_room_path(code: room_code)
    assert_equal "Please join a room first.", flash[:alert]
  end

  test "GET show redirects to join form when no session even with invalid code" do
    get room_path("SOMECODE")

    # Even invalid codes redirect to join form (validation happens on join)
    assert_redirected_to join_room_path(code: "SOMECODE")
  end

  test "GET show redirects when room not found in session" do
    post rooms_path, params: { name: "Admin" }
    follow_redirect!
    room_code = session[:room_code]

    # Simulate room being deleted
    RoomStore.reset!

    get room_path(room_code)

    assert_redirected_to root_path
    assert_equal "Room not found.", flash[:alert]
  end

  test "session is set correctly after create" do
    post rooms_path, params: { name: "Alice" }
    follow_redirect!

    assert session[:room_code].present?
    assert session[:participant_id].present?
    assert_equal "Alice", session[:participant_name]
    assert session[:room_admin]
  end

  test "session is set correctly after join" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    post join_room_with_code_path(room_code), params: { code: room_code, name: "Bob" }
    follow_redirect!

    assert_equal room_code, session[:room_code]
    assert session[:participant_id].present?
    assert_equal "Bob", session[:participant_name]
    refute session[:room_admin]
  end

  test "create shows success notice" do
    post rooms_path, params: { name: "Alice" }

    assert_equal "Room created! Share the link to invite others.", flash[:notice]
  end

  test "join shows success notice" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    post join_room_with_code_path(room_code), params: { code: room_code, name: "Bob" }

    assert_equal "Joined the room!", flash[:notice]
  end

  test "room show page displays participant name" do
    post rooms_path, params: { name: "Alice" }
    follow_redirect!
    room_code = session[:room_code]

    get room_path(room_code)

    assert_response :success
    assert_select ".room__participant", text: /Alice/
  end

  test "room show page displays room code" do
    post rooms_path, params: { name: "Alice" }
    follow_redirect!
    room_code = session[:room_code]

    get room_path(room_code)

    assert_response :success
    assert_select ".room__code", text: /#{room_code}/
  end

  test "room show page share input contains join URL with code" do
    post rooms_path, params: { name: "Alice" }
    follow_redirect!
    room_code = session[:room_code]

    get room_path(room_code)

    assert_response :success
    assert_select "input[data-room-target=shareInput][readonly]"
    assert_match %r{/rooms/join\?code=#{room_code}}, response.body, "Share link should be join URL with room code"
  end

  test "POST join accepts lowercase room code" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code
    lowercase_code = room_code.downcase

    post join_room_with_code_path(lowercase_code), params: { code: lowercase_code, name: "Bob" }

    assert_redirected_to room_path(room_code)
    assert_equal "Bob", session[:participant_name]
  end
end
