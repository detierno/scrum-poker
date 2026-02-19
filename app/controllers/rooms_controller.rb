# frozen_string_literal: true

class RoomsController < ApplicationController
  before_action :require_room_session, only: %i[show]
  before_action :load_room, only: %i[show]

  def show
    @room_code = session[:room_code]
    @participant_id = session[:participant_id]
    @is_admin = session[:room_admin]
    @participant_name = session[:participant_name]
  end

  def create
    result = RoomStore.instance.create_room(admin_name: params.require(:name))
    room = result[:room]
    admin_id = result[:admin_id]

    set_room_session(room.code, admin_id, params[:name], true)
    redirect_to room_path(room.code), notice: "Room created! Share the link to invite others."
  end

  def join
    result = RoomStore.instance.join_room(
      code: params.require(:code),
      participant_name: params.require(:name)
    )
    room = result[:room]
    participant_id = result[:participant_id]

    set_room_session(room.code, participant_id, params[:name], false)
    redirect_to room_path(room.code), notice: "Joined the room!"
  rescue RoomStore::NotFoundError
    redirect_to root_path, alert: "Room not found. Please check the code and try again."
  end

  def join_form
    @code = params[:code]
    redirect_to root_path and return if @code.blank?
  end

  private

  def require_room_session
    return if session[:room_code].present? && session[:participant_id].present?

    # If visiting with a room code in URL, redirect to join form
    code = params[:code]
    redirect_to(code ? join_room_path(code: code) : root_path, alert: "Please join a room first.")
  end

  def load_room
    @room = RoomStore.instance.find_room(session[:room_code])
    redirect_to root_path, alert: "Room not found." unless @room
  end

  def set_room_session(room_code, participant_id, participant_name, is_admin)
    session[:room_code] = room_code
    session[:participant_id] = participant_id
    session[:participant_name] = participant_name
    session[:room_admin] = is_admin
  end
end
