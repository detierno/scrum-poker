module ApplicationHelper
  # Full URL for the join form with room code, so invitees land on "enter your name" with code pre-filled.
  # Uses the current request's host and port so the share link matches the URL you're actually using.
  def shareable_room_url(room_code)
    if request.present?
      "#{request.base_url}#{join_room_path(code: room_code)}"
    else
      join_room_url(code: room_code)
    end
  end
end
