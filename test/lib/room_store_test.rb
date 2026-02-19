# frozen_string_literal: true

require "test_helper"

class RoomStoreTest < ActiveSupport::TestCase
  setup do
    RoomStore.reset!
  end

  test "create_room returns room and admin_id" do
    result = RoomStore.instance.create_room(admin_name: "Alice")

    assert result[:room].is_a?(RoomStore::Room)
    assert result[:admin_id].present?
    assert_equal "Alice", result[:room].participants[result[:admin_id]][:name]
  end

  test "create_room generates 6-char uppercase code" do
    result = RoomStore.instance.create_room(admin_name: "Alice")
    room = result[:room]

    assert_match(/\A[A-Z]{6}\z/, room.code)
  end

  test "join_room adds participant" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    join_result = RoomStore.instance.join_room(code: room_code, participant_name: "Bob")

    assert join_result[:participant_id].present?
    assert_equal 2, join_result[:room].participants.size
    assert_equal "Bob", join_result[:room].participants[join_result[:participant_id]][:name]
  end

  test "join_room raises NotFoundError for invalid code" do
    assert_raises(RoomStore::NotFoundError) do
      RoomStore.instance.join_room(code: "INVALID", participant_name: "Bob")
    end
  end

  test "vote records point" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 5)

    assert_equal 5, room.participants[admin_id][:vote]
  end

  test "vote only accepts fibonacci points" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 4)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 7)
    assert RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 8)
  end

  test "everyone_voted? returns true when all have voted" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]
    join_result = RoomStore.instance.join_room(code: room.code, participant_name: "Bob")
    bob_id = join_result[:participant_id]

    refute room.everyone_voted?

    RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 5)
    refute room.everyone_voted?

    RoomStore.instance.vote(room_code: room.code, participant_id: bob_id, point: 8)
    assert room.everyone_voted?
  end

  test "reveal sets revealed to true" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    RoomStore.instance.reveal(room_code: room.code, participant_id: admin_id)

    assert room.revealed
  end

  test "reveal raises for non-admin" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    join_result = RoomStore.instance.join_room(code: room.code, participant_name: "Bob")
    bob_id = join_result[:participant_id]

    assert_raises(ArgumentError, "Only admin can reveal") do
      RoomStore.instance.reveal(room_code: room.code, participant_id: bob_id)
    end
  end

  test "reset_voting clears all votes" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]
    join_result = RoomStore.instance.join_room(code: room.code, participant_name: "Bob")
    bob_id = join_result[:participant_id]

    RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 5)
    RoomStore.instance.vote(room_code: room.code, participant_id: bob_id, point: 8)
    RoomStore.instance.reveal(room_code: room.code, participant_id: admin_id)

    RoomStore.instance.reset_voting(room_code: room.code, participant_id: admin_id)

    assert_nil room.participants[admin_id][:vote]
    assert_nil room.participants[bob_id][:vote]
    refute room.revealed
  end

  test "vote returns false for invalid participant" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]

    result = RoomStore.instance.vote(room_code: room.code, participant_id: "invalid-id", point: 5)

    assert_equal false, result
  end

  test "vote returns false for non-fibonacci point" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 0)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 4)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 6)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 7)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 9)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 10)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 11)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 12)
    refute RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: 14)
  end

  test "vote accepts all fibonacci points" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    RoomStore::Room::FIBONACCI_POINTS.each do |point|
      assert RoomStore.instance.vote(room_code: room.code, participant_id: admin_id, point: point),
             "Should accept fibonacci point #{point}"
    end
  end

  test "add_participant prevents duplicate participant ids" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    result = room.add_participant(participant_id: admin_id, name: "Duplicate")

    assert_equal false, result
    assert_equal 1, room.participants.size
  end

  test "find_room is case insensitive" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room_code = create_result[:room].code

    assert RoomStore.instance.find_room(room_code.downcase)
    assert RoomStore.instance.find_room(room_code.upcase)
    assert RoomStore.instance.find_room(room_code)
  end

  test "find_room returns nil for non-existent room" do
    assert_nil RoomStore.instance.find_room("NONEXISTENT")
  end

  test "reset_voting raises for non-admin" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    join_result = RoomStore.instance.join_room(code: room.code, participant_name: "Bob")
    bob_id = join_result[:participant_id]

    assert_raises(ArgumentError, "Only admin can reset") do
      RoomStore.instance.reset_voting(room_code: room.code, participant_id: bob_id)
    end
  end

  test "vote raises NotFoundError for invalid room" do
    assert_raises(RoomStore::NotFoundError) do
      RoomStore.instance.vote(room_code: "INVALID", participant_id: "some-id", point: 5)
    end
  end

  test "reveal raises NotFoundError for invalid room" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    admin_id = create_result[:admin_id]

    assert_raises(RoomStore::NotFoundError) do
      RoomStore.instance.reveal(room_code: "INVALID", participant_id: admin_id)
    end
  end

  test "reset_voting raises NotFoundError for invalid room" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    admin_id = create_result[:admin_id]

    assert_raises(RoomStore::NotFoundError) do
      RoomStore.instance.reset_voting(room_code: "INVALID", participant_id: admin_id)
    end
  end

  test "room as_json includes all required fields" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]

    json = room.as_json

    assert json.key?(:code)
    assert json.key?(:participants)
    assert json.key?(:revealed)
    assert json.key?(:everyone_voted)
    assert json.key?(:fibonacci_points)
    assert_equal RoomStore::Room::FIBONACCI_POINTS, json[:fibonacci_points]
  end

  test "room participants returns hash with name and vote only" do
    create_result = RoomStore.instance.create_room(admin_name: "Admin")
    room = create_result[:room]
    admin_id = create_result[:admin_id]

    participants = room.participants

    assert participants[admin_id].key?(:name)
    assert participants[admin_id].key?(:vote)
    assert_equal 2, participants[admin_id].keys.size
  end

  test "multiple rooms can exist simultaneously" do
    room1 = RoomStore.instance.create_room(admin_name: "Admin1")
    room2 = RoomStore.instance.create_room(admin_name: "Admin2")

    assert_not_equal room1[:room].code, room2[:room].code
    assert RoomStore.instance.find_room(room1[:room].code)
    assert RoomStore.instance.find_room(room2[:room].code)
  end

  test "room codes are unique" do
    codes = 10.times.map do
      RoomStore.instance.create_room(admin_name: "Admin")[:room].code
    end

    assert_equal codes.size, codes.uniq.size
  end
end
