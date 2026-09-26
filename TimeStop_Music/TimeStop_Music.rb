#----------------------------------------------------------------
#  TimeStop_Music.rb
#
#  Changelog:
#      Paulinchen  2026-09-26: Created
#
#----------------------------------------------------------------

# Keeps the battle music playing through time stop.
# The game fades it to silence when time stops and back up to full volume when time resumes.
# The screen effect is left as it is.
class << Audio
  # Leaves the music as it is when time stops.
  def start_over_drive
  end

  # Leaves the music as it is when time resumes, which also keeps each track's own volume.
  def end_over_drive
  end
end
