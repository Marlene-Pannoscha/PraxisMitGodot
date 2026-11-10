extends SceneTree

func _initialize() -> void:
	call_deferred("aufnehmen")

func aufnehmen() -> void:
	var szene = load("res://Main.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	szene.set_process(false)
	szene._start_pause()
	szene.simulation.Fortschalten(22.5)
	szene._start_pause()
	szene._aktualisiere_patienten(0)
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var pfad := ProjectSettings.globalize_path("res://../Vorschau.png")
	root.get_texture().get_image().save_png(pfad)
	print("3D-Vorschau: " + pfad)
	quit()
