# frozen_string_literal: true

require "test_helper"

class RoomTest < ActiveSupport::TestCase
  setup do
    @room = RoomStore::Room.new(
      code: "TEST01",
      admin_id: "admin-123",
      admin_name: "Admin"
    )
  end

  test "room initializes with admin" do
    assert_equal "TEST01", @room.code
    assert_equal "admin-123", @room.admin_id
    assert_equal "Admin", @room.participants["admin-123"][:name]
    assert_nil @room.participants["admin-123"][:vote]
    refute @room.revealed
  end

  test "room has created_at timestamp" do
    assert @room.created_at.is_a?(Time)
    assert @room.created_at <= Time.current
  end

  test "add_participant adds new participant" do
    result = @room.add_participant(participant_id: "user-456", name: "Bob")

    assert result
    assert_equal 2, @room.participants.size
    assert_equal "Bob", @room.participants["user-456"][:name]
    assert_nil @room.participants["user-456"][:vote]
  end

  test "add_participant returns false for duplicate id" do
    @room.add_participant(participant_id: "user-456", name: "Bob")
    result = @room.add_participant(participant_id: "user-456", name: "Duplicate")

    refute result
    assert_equal 2, @room.participants.size
    assert_equal "Bob", @room.participants["user-456"][:name]
  end

  test "vote records point for valid participant" do
    @room.add_participant(participant_id: "user-456", name: "Bob")

    result = @room.vote(participant_id: "user-456", point: 5)

    assert result
    assert_equal 5, @room.participants["user-456"][:vote]
  end

  test "vote returns false for invalid participant" do
    result = @room.vote(participant_id: "invalid-id", point: 5)

    refute result
  end

  test "vote returns false for invalid point" do
    @room.add_participant(participant_id: "user-456", name: "Bob")

    refute @room.vote(participant_id: "user-456", point: 4)
    refute @room.vote(participant_id: "user-456", point: 0)
    refute @room.vote(participant_id: "user-456", point: 20)
  end

  test "vote accepts all fibonacci points" do
    @room.add_participant(participant_id: "user-456", name: "Bob")

    RoomStore::Room::FIBONACCI_POINTS.each do |point|
      assert @room.vote(participant_id: "user-456", point: point),
             "Should accept fibonacci point #{point}"
      assert_equal point, @room.participants["user-456"][:vote]
      # Reset for next test
      @room.participants["user-456"][:vote] = nil
    end
  end

  test "everyone_voted? returns false when no votes" do
    @room.add_participant(participant_id: "user-456", name: "Bob")

    refute @room.everyone_voted?
  end

  test "everyone_voted? returns false when some votes" do
    @room.add_participant(participant_id: "user-456", name: "Bob")
    @room.vote(participant_id: "admin-123", point: 5)

    refute @room.everyone_voted?
  end

  test "everyone_voted? returns true when all voted" do
    @room.add_participant(participant_id: "user-456", name: "Bob")
    @room.vote(participant_id: "admin-123", point: 5)
    @room.vote(participant_id: "user-456", point: 8)

    assert @room.everyone_voted?
  end

  test "admin? returns true for admin" do
    assert @room.admin?("admin-123")
  end

  test "admin? returns false for non-admin" do
    @room.add_participant(participant_id: "user-456", name: "Bob")

    refute @room.admin?("user-456")
    refute @room.admin?("invalid-id")
  end

  test "clear_votes! clears all votes and resets revealed" do
    @room.add_participant(participant_id: "user-456", name: "Bob")
    @room.vote(participant_id: "admin-123", point: 5)
    @room.vote(participant_id: "user-456", point: 8)
    @room.revealed = true

    @room.clear_votes!

    assert_nil @room.participants["admin-123"][:vote]
    assert_nil @room.participants["user-456"][:vote]
    refute @room.revealed
  end

  test "participants returns hash with name and vote only" do
    @room.add_participant(participant_id: "user-456", name: "Bob")
    @room.vote(participant_id: "admin-123", point: 5)

    participants = @room.participants

    assert participants["admin-123"].key?(:name)
    assert participants["admin-123"].key?(:vote)
    assert_equal 2, participants["admin-123"].keys.size
    assert_equal "Admin", participants["admin-123"][:name]
    assert_equal 5, participants["admin-123"][:vote]
  end

  test "as_json includes all required fields" do
    json = @room.as_json

    assert json.key?(:code)
    assert json.key?(:participants)
    assert json.key?(:revealed)
    assert json.key?(:everyone_voted)
    assert json.key?(:fibonacci_points)
    assert_equal "TEST01", json[:code]
    assert_equal RoomStore::Room::FIBONACCI_POINTS, json[:fibonacci_points]
  end

  test "as_json updates everyone_voted correctly" do
    @room.add_participant(participant_id: "user-456", name: "Bob")

    json = @room.as_json
    refute json[:everyone_voted]

    @room.vote(participant_id: "admin-123", point: 5)
    @room.vote(participant_id: "user-456", point: 8)

    json = @room.as_json
    assert json[:everyone_voted]
  end

  test "revealed can be set" do
    refute @room.revealed

    @room.revealed = true
    assert @room.revealed

    @room.revealed = false
    refute @room.revealed
  end
end
