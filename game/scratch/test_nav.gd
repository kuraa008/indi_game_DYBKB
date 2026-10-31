extends SceneTree

func _init() -> void:
	print("--- TESTING NAVMESH & PATHFINDING ---")
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait 2 frames for bake to finish
	var nav_reg: NavigationRegion3D = main_scene.find_child("NavRegion", true, false)
	if not nav_reg:
		print("ERROR: NavRegion not found!")
		quit()
		return
	
	# Force synchronous bake
	var nm = nav_reg.navigation_mesh
	print("NavMesh settings:")
	print("  cell_size: ", nm.cell_size)
	print("  cell_height: ", nm.cell_height)
	print("  agent_radius: ", nm.agent_radius)
	print("  agent_height: ", nm.agent_height)
	print("  parsed_geometry_type: ", nm.geometry_parsed_geometry_type)
	print("  collision_mask: ", nm.geometry_collision_mask)
	
	# Synchronous bake
	NavigationServer3D.bake_from_source_geometry_data(nm, NavigationMeshSourceGeometryData3D.new())
	var nav_source = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, nav_source, nav_reg)
	NavigationServer3D.bake_from_source_geometry_data(nm, nav_source)
	
	print("Polygons baked: ", nm.get_polygon_count())
	print("Vertices count: ", nm.get_vertices().size())
	
	# Test path from enemy spawn to player spawn
	var p_start = main_scene.get("enemy_spawn")
	var p_end = main_scene.get("player_spawn")
	print("Start (Enemy spawn): ", p_start)
	print("End (Player spawn): ", p_end)
	
	var nav_map = nav_reg.get_navigation_map()
	NavigationServer3D.region_set_navigation_mesh(nav_reg.get_region_rid(), nm)
	NavigationServer3D.region_set_transform(nav_reg.get_region_rid(), nav_reg.global_transform)
	NavigationServer3D.region_set_map(nav_reg.get_region_rid(), nav_map)
	
	# Wait for server sync
	var path = NavigationServer3D.map_get_path(nav_map, p_start, p_end, true)
	print("Computed path points: ", path.size())
	for i in range(min(5, path.size())):
		print("  pt[", i, "]: ", path[i])
	
	quit()
