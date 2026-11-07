extends SceneTree

# Runs tests/expanded_goods_production_validation.gd, which extends RefCounted and so can't be
# given to --script itself. Exits non-zero on any failure, like the other tests.

const Validation = preload("res://tests/expanded_goods_production_validation.gd")

func _init() -> void:
	var validation = Validation.new()
	validation.run_all()
	if validation.failure_count > 0:
		print("expanded goods production: %d failures" % validation.failure_count)
		quit(1)
		return
	print("expanded goods production: all checks passed")
	quit(0)
