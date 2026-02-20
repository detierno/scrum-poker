# frozen_string_literal: true

class RoomChannel < ApplicationCable::Channel
  def subscribed
    @room_code = params[:room_code]
    @participant_id = params[:participant_id]
    @room = RoomStore.instance.find_room(@room_code)

    reject unless @room && participant_in_room?

    stream_from room_stream_name
    broadcast_room_state
  end

  def unsubscribed
    # No cleanup; room state is server-side only
  end

  def vote(data)
    point = data["point"]&.to_i
    return unless point && RoomStore::Room::FIBONACCI_POINTS.include?(point)

    RoomStore.instance.vote(room_code: @room_code, participant_id: @participant_id, point: point)
    broadcast_room_state
  end

  def reveal
    return unless @room.admin?(@participant_id)

    RoomStore.instance.reveal(room_code: @room_code, participant_id: @participant_id)
    broadcast_room_state
  end

  def reset_voting
    return unless @room.admin?(@participant_id)

    RoomStore.instance.reset_voting(room_code: @room_code, participant_id: @participant_id)
    broadcast_room_state
  end

  private

  def participant_in_room?
    @room.participants.key?(@participant_id)
  end

  def room_stream_name
    "room:#{@room_code}"
  end

  def broadcast_room_state
    room = RoomStore.instance.find_room(@room_code)
    return unless room

    ActionCable.server.broadcast(room_stream_name, room.as_json.merge(room_code: @room_code))
  end
end
