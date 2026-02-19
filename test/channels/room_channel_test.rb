# frozen_string_literal: true

require "test_helper"

class RoomChannelTest < ActionCable::Channel::TestCase
  setup do
    RoomStore.reset!
    @create_result = RoomStore.instance.create_room(admin_name: "Admin")
    @room_code = @create_result[:room].code
    @admin_id = @create_result[:admin_id]
    @join_result = RoomStore.instance.join_room(code: @room_code, participant_name: "Bob")
    @bob_id = @join_result[:participant_id]
  end

  test "subscribes and streams from room" do
    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    assert subscription.confirmed?
    assert_has_stream "room:#{@room_code}"
  end

  test "rejects subscription for invalid room" do
    stub_connection
    subscribe(room_code: "INVALID", participant_id: @admin_id)

    assert subscription.rejected?
  end

  test "rejects subscription for participant not in room" do
    stub_connection
    subscribe(room_code: @room_code, participant_id: "fake-uuid")

    assert subscription.rejected?
  end

  test "vote performs action and broadcasts" do
    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    assert_broadcasts("room:#{@room_code}", 1) do
      perform :vote, point: 5
    end

    room = RoomStore.instance.find_room(@room_code)
    assert_equal 5, room.participants[@admin_id][:vote]
  end

  test "reveal performs when admin" do
    RoomStore.instance.vote(room_code: @room_code, participant_id: @admin_id, point: 5)
    RoomStore.instance.vote(room_code: @room_code, participant_id: @bob_id, point: 8)

    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    perform :reveal

    room = RoomStore.instance.find_room(@room_code)
    assert room.revealed
  end

  test "reset_voting clears votes when admin" do
    RoomStore.instance.vote(room_code: @room_code, participant_id: @admin_id, point: 5)
    RoomStore.instance.reveal(room_code: @room_code, participant_id: @admin_id)

    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    perform :reset_voting

    room = RoomStore.instance.find_room(@room_code)
    refute room.revealed
    assert_nil room.participants[@admin_id][:vote]
  end

  test "vote rejects invalid fibonacci points" do
    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    perform :vote, point: 4

    room = RoomStore.instance.find_room(@room_code)
    assert_nil room.participants[@admin_id][:vote]
  end

  test "vote accepts all valid fibonacci points" do
    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    RoomStore::Room::FIBONACCI_POINTS.each do |point|
      perform :vote, point: point
      room = RoomStore.instance.find_room(@room_code)
      assert_equal point, room.participants[@admin_id][:vote]
    end
  end

  test "reveal does nothing when not admin" do
    RoomStore.instance.vote(room_code: @room_code, participant_id: @admin_id, point: 5)
    RoomStore.instance.vote(room_code: @room_code, participant_id: @bob_id, point: 8)

    stub_connection
    subscribe(room_code: @room_code, participant_id: @bob_id)

    perform :reveal

    room = RoomStore.instance.find_room(@room_code)
    refute room.revealed
  end

  test "reset_voting does nothing when not admin" do
    RoomStore.instance.vote(room_code: @room_code, participant_id: @admin_id, point: 5)
    RoomStore.instance.reveal(room_code: @room_code, participant_id: @admin_id)

    stub_connection
    subscribe(room_code: @room_code, participant_id: @bob_id)

    perform :reset_voting

    room = RoomStore.instance.find_room(@room_code)
    assert room.revealed
  end

  test "broadcasts room state after vote" do
    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    assert_broadcasts("room:#{@room_code}", 1) do
      perform :vote, point: 5
    end
  end

  test "broadcasts room state after reveal" do
    RoomStore.instance.vote(room_code: @room_code, participant_id: @admin_id, point: 5)
    RoomStore.instance.vote(room_code: @room_code, participant_id: @bob_id, point: 8)

    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    assert_broadcasts("room:#{@room_code}", 1) do
      perform :reveal
    end
  end

  test "broadcasts room state after reset" do
    RoomStore.instance.vote(room_code: @room_code, participant_id: @admin_id, point: 5)
    RoomStore.instance.reveal(room_code: @room_code, participant_id: @admin_id)

    stub_connection
    subscribe(room_code: @room_code, participant_id: @admin_id)

    assert_broadcasts("room:#{@room_code}", 1) do
      perform :reset_voting
    end
  end

  test "broadcasts room state on subscription" do
    stub_connection

    assert_broadcasts("room:#{@room_code}", 1) do
      subscribe(room_code: @room_code, participant_id: @admin_id)
    end
  end
end
