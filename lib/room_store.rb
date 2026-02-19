# frozen_string_literal: true

require "securerandom"

class RoomStore
  class Room
    FIBONACCI_POINTS = [ 1, 2, 3, 5, 8, 13 ].freeze

    attr_reader :code, :admin_id, :created_at
    attr_accessor :revealed

    def initialize(code:, admin_id:, admin_name:)
      @code = code
      @admin_id = admin_id
      @participants = { admin_id => { name: admin_name, vote: nil } }
      @revealed = false
      @created_at = Time.current
    end

    def participants
      @participants.transform_values { |data| data.slice(:name, :vote) }
    end

    def add_participant(participant_id:, name:)
      return false if @participants.key?(participant_id)

      @participants[participant_id] = { name: name, vote: nil }
      true
    end

    def vote(participant_id:, point:)
      return false unless @participants.key?(participant_id)
      return false unless FIBONACCI_POINTS.include?(point)

      @participants[participant_id][:vote] = point
      true
    end

    def everyone_voted?
      @participants.values.all? { |data| !data[:vote].nil? }
    end

    def admin?(participant_id)
      participant_id == @admin_id
    end

    def clear_votes!
      @participants.each_value { |data| data[:vote] = nil }
      @revealed = false
    end

    def as_json
      {
        code: code,
        participants: participants,
        revealed: revealed,
        everyone_voted: everyone_voted?,
        fibonacci_points: FIBONACCI_POINTS
      }
    end
  end

  class NotFoundError < StandardError; end

  def self.instance
    @instance ||= new
  end

  def self.reset!
    @instance = new
  end

  def initialize
    @rooms = {}
    @mutex = Mutex.new
  end

  def create_room(admin_name:)
    admin_id = SecureRandom.uuid
    code = generate_code
    room = Room.new(code: code, admin_id: admin_id, admin_name: admin_name)

    @mutex.synchronize do
      @rooms[code] = room
    end

    { room: room, admin_id: admin_id }
  end

  def find_room(code)
    @mutex.synchronize { @rooms[code.to_s.upcase] }
  end

  def join_room(code:, participant_name:)
    room = find_room(code)
    raise NotFoundError unless room

    participant_id = SecureRandom.uuid
    success = room.add_participant(participant_id: participant_id, name: participant_name)
    raise NotFoundError unless success

    { room: room, participant_id: participant_id }
  end

  def vote(room_code:, participant_id:, point:)
    room = find_room(room_code)
    raise NotFoundError unless room

    room.vote(participant_id: participant_id, point: point)
  end

  def reveal(room_code:, participant_id:)
    room = find_room(room_code)
    raise NotFoundError unless room
    raise ArgumentError, "Only admin can reveal" unless room.admin?(participant_id)

    room.revealed = true
  end

  def reset_voting(room_code:, participant_id:)
    room = find_room(room_code)
    raise NotFoundError unless room
    raise ArgumentError, "Only admin can reset" unless room.admin?(participant_id)

    @mutex.synchronize { room.clear_votes! }
  end

  private

  def generate_code
    loop do
      code = 6.times.map { ("A".."Z").to_a.sample }.join
      return code unless @rooms.key?(code)
    end
  end
end
