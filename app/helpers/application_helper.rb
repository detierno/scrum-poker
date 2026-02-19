module ApplicationHelper
  # Build join-form URL so invitees land directly on "enter your name" with code pre-filled.
  # Format: http://localhost:3001/rooms/join?code=DAHGEU
  def shareable_room_url(room_code)
    path = join_room_path(code: room_code)
    base = "#{request.protocol}#{request.host_with_port}"
    "#{base}#{path}"
  end
end
