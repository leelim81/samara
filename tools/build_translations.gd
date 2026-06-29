extends SceneTree
# Build text.en/es.translation directly from text/text.csv, bypassing the
# (currently hanging) editor CSV-import. Run headless:
#   godot --headless --path . --script res://tools/build_translations.gd
# Produces the same Translation resources the importer would, then quits.

func _init():
	var f := FileAccess.open("res://text/text.csv", FileAccess.READ)
	if f == null:
		push_error("cannot open res://text/text.csv")
		quit(1)
		return
	var en := Translation.new(); en.locale = "en"
	var es := Translation.new(); es.locale = "es"
	f.get_csv_line() # skip header: keys,en,es
	var n := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2:
			continue
		var key := row[0]
		if key == "":
			continue
		var en_v := row[1]
		var es_v := row[2] if row.size() > 2 else en_v
		en.add_message(key, en_v)
		es.add_message(key, es_v)
		n += 1
	f.close()
	var r1 := ResourceSaver.save(en, "res://text/text.en.translation")
	var r2 := ResourceSaver.save(es, "res://text/text.es.translation")
	print("rows=%d save_en=%d save_es=%d" % [n, r1, r2])
	quit(0 if (r1 == OK and r2 == OK) else 2)
