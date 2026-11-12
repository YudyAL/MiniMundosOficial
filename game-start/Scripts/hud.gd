extends CanvasLayer
# Añade un CanvasLayer con este script a tu nivel. Crea el HUD solo por código.

var label := Label.new()
var bar := ProgressBar.new()

func _ready() -> void:
    label.position = Vector2(20, 16)
    label.add_theme_font_size_override("font_size", 24)
    add_child(label)
    bar.position = Vector2(20, 60)
    bar.size = Vector2(220, 16)
    bar.max_value = Game.STREAK_WINDOW
    bar.show_percentage = false
    add_child(bar)

func _process(_delta: float) -> void:
    label.text = "Destellos %d/%d   Racha x%d   Puntos %d" % [
        Game.calmed, Game.TOTAL_DESTELLOS, Game.streak, Game.score]
    bar.value = Game.streak_left
