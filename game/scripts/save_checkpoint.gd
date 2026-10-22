extends RefCounted
## Persist stable puzzle milestones, not transient velocity, casting or cinematic state.
func stable(room: Node) -> int:
	if room.casting or room.interacting or room.seal_active or room.arrival_busy():return -1
	if absf(room.state.rail_speed)>0.1 or absf(room.state.vertical_speed)>0.1:return -1
	var result: int=room.state.stage()
	if result==5 and not room.gate_ready:return -1
	return result

func restore(room: Node,checkpoint: int) -> void:
	var stage:=clampi(checkpoint,0,5)
	room.reset_tutorial()
	var state=room.state
	state.first_latched=stage>=2
	state.receiver_latched=stage>=4
	state.rail_position=0.0 if stage==0 else (state.FIRST_STOP if stage<=2 else state.RAIL_LENGTH)
	state.world=state.World.INVERTED if stage==4 else (state.World.HEAVY if stage in [2,5] else state.World.ICE)
	state.elevation=state.CEILING if stage==4 else 0.0
	state.rail_speed=0.0;state.vertical_speed=0.0
	state._update_contacts()
	room.gate_ready=stage==5;room.seal_completed=stage==5;room.seal_age=room.SEAL_DURATION if stage==5 else 0.0
	room._gate_open=room.gate_ready
	room.gate_collision.set_deferred("disabled",room.gate_ready)
	room._refresh_navigation=2
	room._last_stage=-1;room._last_goal=-1
	room.weight_art.position=room.block_ground_position()
	room.hud.refresh(state);room.orbit_view._sync_state(0.0)
	room.hud.message("已恢复观测记录："+["准备校准","镇纸已到星位","星位已定","镇纸已到末端","月痕已稳","界缝已封"][stage])
