extends Node

# Sound effects
var sounds = {
	"select": preload("res://assets/audio/select.ogg"),
	"explosion": preload("res://assets/audio/explosion.ogg"),
	"forceField": preload("res://assets/audio/forceField.ogg"),
	"spaceEngine": preload("res://assets/audio/spaceEngine.ogg"),
	"powerup": preload("res://assets/audio/powerup.ogg")
}

# Music
var music_track = preload("res://assets/audio/music.mp3")

# AudioStreamPlayer nodes for different types of sounds
var sfx_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer  # Separate player for looping engine sound
var music_player: AudioStreamPlayer   # Separate player for background music

func _ready():
	# Create AudioStreamPlayer nodes
	sfx_player = AudioStreamPlayer.new()
	engine_player = AudioStreamPlayer.new()
	music_player = AudioStreamPlayer.new()
	
	add_child(sfx_player)
	add_child(engine_player)
	add_child(music_player)
	
	# Set up engine player for looping
	engine_player.finished.connect(_on_engine_finished)
	
	# Set up music player
	music_player.stream = music_track
	music_player.volume_db = -15.0  # Quieter background music
	music_player.finished.connect(_on_music_finished)

func play_sound(sound_name: String, volume: float = 0.0):
	if sound_name in sounds:
		sfx_player.stream = sounds[sound_name]
		sfx_player.volume_db = volume
		sfx_player.play()
	else:
		print("Sound not found: " + sound_name)

func play_engine(volume: float = -5.0):
	if not engine_player.playing:
		engine_player.stream = sounds["spaceEngine"]
		engine_player.volume_db = volume
		engine_player.play()

func stop_engine():
	if engine_player.playing:
		engine_player.stop()

func _on_engine_finished():
	# Loop the engine sound
	if engine_player.stream == sounds["spaceEngine"]:
		engine_player.play()

func _on_music_finished():
	# Loop the background music
	music_player.play()

# Music control functions
func start_music():
	if not music_player.playing:
		music_player.play()

func stop_music():
	if music_player.playing:
		music_player.stop()

func restart_music():
	music_player.stop()
	music_player.play()

# Convenience functions
func play_select():
	play_sound("select")

func play_explosion():
	play_sound("explosion")

func play_force_field():
	play_sound("forceField")

func play_powerup():
	play_sound("powerup")

func play_space_engine():
	play_engine()
