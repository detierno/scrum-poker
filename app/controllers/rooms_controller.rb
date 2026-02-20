# frozen_string_literal: true

class RoomsController < ApplicationController
  before_action :require_room_session, only: %i[show]
  before_action :load_room, only: %i[show]
  before_action :set_room_assigns, only: %i[show]

  def show
    # Assigns set by set_room_assigns
  end

  def create
    name = params.require(:name)
    result = RoomStore.instance.create_room(admin_name: name)
    room = result[:room]
    admin_id = result[:admin_id]

    set_room_session(room.code, admin_id, name, true)
    redirect_to room_path(room.code), notice: "Room created! Share the link to invite others."
  end

  def join
    name = params.require(:name)
    result = RoomStore.instance.join_room(
      code: params[:code],
      participant_name: name
    )
    room = result[:room]
    participant_id = result[:participant_id]

    set_room_session(room.code, participant_id, name, false)
    redirect_to room_path(room.code), notice: "Joined the room!"
  rescue RoomStore::NotFoundError
    redirect_to root_path, alert: "Room not found. Please check the code and try again."
  end

  def join_form
    @code = params[:code]
    if @code.blank?
      redirect_to root_path, alert: "Please enter a room code."
      return
    end
  end

  private

  def require_room_session
    return if session[:room_code].present? && session[:participant_id].present?

    code = params[:code]
    path = code.present? ? join_room_path(code: code) : root_path
    redirect_to path, alert: "Please join a room first."
  end

  def load_room
    @room = RoomStore.instance.find_room(session[:room_code])
    redirect_to root_path, alert: "Room not found." unless @room
  end

  def set_room_assigns
    return unless @room

    @room_code = session[:room_code]
    @participant_id = session[:participant_id]
    @participant_name = session[:participant_name]
    @is_admin = session[:room_admin]
    @vote_options = RoomStore::Room::FIBONACCI_POINTS
  end

  def set_room_session(room_code, participant_id, participant_name, is_admin)
    session[:room_code] = room_code
    session[:participant_id] = participant_id
    session[:participant_name] = participant_name
    session[:room_admin] = is_admin
  end
end
