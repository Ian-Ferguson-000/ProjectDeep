extends Node2D
class_name SlasherActiveItemVfx

## A lightweight, code-driven animation layer shared by the authored active
## items. Each item owns a distinct silhouette, palette, and motion language;
## combat runtimes remain responsible for damage and status mechanics.

var actor:Node2D
var item_id:=""
var motif:="burst"
var primary:=Color.WHITE
var secondary:=Color("#82d8ff")
var elapsed:=0.0
var duration:=0.0
var direction:=Vector2.RIGHT
var motes:Array[Dictionary]=[]

const LOOKS:Dictionary={
	# Fighter
	"eldritch_bowstaff":["runes",Color("#a85cff"),Color("#67f0bd")],
	"demon_blade":["blood_flame",Color("#ff334f"),Color("#ff9b43")],
	"storm_trident":["lightning",Color("#7be8ff"),Color("#f6fbff")],
	"valkyrian_sling":["wings",Color("#f8d76d"),Color("#f7f2d3")],
	"dragonbone_dagger":["wounds",Color("#ead7b0"),Color("#d84b43")],
	"archon_crossbow":["piercing_bolt",Color("#b9d0dc"),Color("#5fa6e6")],
	"divine_hammer":["sun_hammer",Color("#ffe77a"),Color("#fff8d5")],
	"grim_reaver":["scythe",Color("#a66cff"),Color("#8bed79")],
	"sentinel_shield":["shield_wave",Color("#5db5ff"),Color("#f2cf69")],
	"umbral_bow":["shadow_tethers",Color("#6655bb"),Color("#d17cff")],
	# Mage
	"michaels_orb":["prism",Color("#ff76da"),Color("#68ebff")],
	"gulthias_staff":["thorn_growth",Color("#7ed35a"),Color("#a6293a")],
	"skyblinder_staff":["radiant_charge",Color("#fffbd0"),Color("#ffd449")],
	"dragonstaff_of_ahghairon":["dragon_fire",Color("#ff5a28"),Color("#ffcf55")],
	"jade_serpent_staff":["serpent",Color("#46d873"),Color("#b6f65c")],
	"arachne_staff":["web",Color("#e9e5ff"),Color("#a677e8")],
	"tome_of_toth":["soul_pages",Color("#62ead5"),Color("#b178ef")],
	"shangos_shatterer":["thunder_vector",Color("#6eaeff"),Color("#ffd95c")],
	"solar_scepter":["solar_flare",Color("#ff9d35"),Color("#fff18a")],
	"drumamus_bargain":["gravity",Color("#8b53d9"),Color("#e05cff")],
	# Neutral
	"siren_song_lyre":["song",Color("#7be0ef"),Color("#f49bdc")],
	"witherbloom_brooche":["bloom",Color("#dff079"),Color("#e66ca6")],
	"white_dragon_mask":["frost",Color("#d9f7ff"),Color("#6ebbe8")],
	"black_titan_crown":["titan",Color("#494258"),Color("#d4ad53")],
	"dissonant_whisper_jar":["wails",Color("#a3f0e5"),Color("#9272c9")],
	"mahoragan_adaption_wheel":["adaption_wheel",Color("#e5c65d"),Color("#c9e8ef")],
	"pandoras_paradoxical_compass":["paradox",Color("#56e2d2"),Color("#dc6af1")],
	"vibranium_tattoo":["momentum",Color("#8d63e8"),Color("#58d7f2")],
	"shadowfell_brand":["shadow_dash",Color("#302453"),Color("#bd6aef")],
	"blood_ruby_gem":["blood_orbit",Color("#d8294b"),Color("#ff7790")],
	"abyssal_sapphire_gem":["pressure",Color("#246ebd"),Color("#62d9ff")],
	"feywild_shawl":["fey_swarm",Color("#75ed9c"),Color("#ef78dc")],
	"bramble_vine_snare":["bramble_wyrm",Color("#62a53e"),Color("#b88542")],
	"heartbreaker_amulet":["heart_links",Color("#ff5275"),Color("#f4b0c2")],
	"war_horn_of_valor":["valor",Color("#f1c85a"),Color("#e4523d")],
}

func configure(owner:Node2D,id:String)->void:
	actor=owner;item_id=id
	var look:Array=LOOKS.get(id,["burst",Color.WHITE,Color("#82d8ff")])
	motif=String(look[0]);primary=look[1];secondary=look[2]
	z_index=95

func play_activation(aim:Vector2)->void:
	direction=aim.normalized() if aim.length_squared()>0.01 else Vector2.RIGHT
	elapsed=0.0;duration=1.15;motes.clear()
	for i in 18:
		var angle:=TAU*float(i)/18.0+sin(float(i)*2.17)*0.16
		motes.append({"angle":angle,"speed":65.0+float(i%5)*18.0,"phase":float(i)*0.71,"size":2.0+float(i%3)})
	queue_redraw()

func _process(delta:float)->void:
	if duration<=0.0:return
	elapsed+=delta
	if elapsed>=duration:duration=0.0;visible=false
	else:visible=true;queue_redraw()

func _draw()->void:
	if duration<=0.0:return
	var p:=clampf(elapsed/duration,0.0,1.0)
	var fade:=1.0-smoothstep(0.72,1.0,p)
	var c1:=Color(primary,fade);var c2:=Color(secondary,fade)
	match motif:
		"runes": _runes(p,c1,c2)
		"blood_flame": _blood_flame(p,c1,c2)
		"lightning": _lightning(p,c1,c2)
		"wings": _wings(p,c1,c2)
		"wounds": _wounds(p,c1,c2)
		"piercing_bolt": _piercing_bolt(p,c1,c2)
		"sun_hammer": _sun(p,c1,c2,true)
		"scythe": _scythe(p,c1,c2)
		"shield_wave": _shield(p,c1,c2)
		"shadow_tethers": _tethers(p,c1,c2)
		"prism": _prism(p,c1,c2)
		"thorn_growth": _thorns(p,c1,c2)
		"radiant_charge": _radiance(p,c1,c2)
		"dragon_fire": _fire_cone(p,c1,c2)
		"serpent": _serpent(p,c1,c2)
		"web": _web(p,c1,c2)
		"soul_pages": _pages(p,c1,c2)
		"thunder_vector": _thunder(p,c1,c2)
		"solar_flare": _sun(p,c1,c2,false)
		"gravity": _gravity(p,c1,c2)
		"song": _song(p,c1,c2)
		"bloom": _bloom(p,c1,c2)
		"frost": _frost(p,c1,c2)
		"titan": _titan(p,c1,c2)
		"wails": _wails(p,c1,c2)
		"adaption_wheel": _wheel(p,c1,c2)
		"paradox": _paradox(p,c1,c2)
		"momentum": _momentum(p,c1,c2)
		"shadow_dash": _shadow(p,c1,c2)
		"blood_orbit": _blood(p,c1,c2)
		"pressure": _pressure(p,c1,c2)
		"fey_swarm": _fey(p,c1,c2)
		"bramble_wyrm": _bramble(p,c1,c2)
		"heart_links": _hearts(p,c1,c2)
		"valor": _valor(p,c1,c2)
		_: _rings(p,c1,c2)

func _rings(p:float,a:Color,b:Color)->void:
	for i in 3:draw_arc(Vector2.ZERO,(18.0+i*17.0)*(0.35+p),0,TAU,40,a if i%2==0 else b,3.0-i*0.5,true)

func _runes(p:float,a:Color,b:Color)->void:
	for i in 7:
		var ang:=TAU*i/7.0+p*3.0;var q:=Vector2.from_angle(ang)*lerpf(20,58,p)
		draw_line(q-Vector2.from_angle(ang+0.8)*6,q+Vector2.from_angle(ang+0.8)*6,a,2.0,true);draw_circle(q,2.5,b)
	draw_arc(Vector2.ZERO,42+p*12,0,TAU,42,b,2.0,true)

func _blood_flame(p:float,a:Color,b:Color)->void:
	for i in 9:
		var x:=(i-4)*7.0;var h:=20+18*sin(i*1.9+p*9.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x-5,10),Vector2(x+5,10),Vector2(x+sin(p*8+i)*5,-h)]),a if i%2==0 else b)

func _lightning(p:float,a:Color,b:Color)->void:
	for j in 3:
		var pts:=PackedVector2Array([Vector2.ZERO])
		for i in range(1,6):pts.append(direction.rotated((j-1)*0.28)*i*24+direction.orthogonal()*sin(i*4.2+p*18+j)*10)
		draw_polyline(pts,b if j==1 else a,4.0 if j==1 else 2.0,true)

func _wings(p:float,a:Color,b:Color)->void:
	for side in [-1.0,1.0]:
		for i in 5:
			var root:Vector2=direction.orthogonal()*float(side)*6.0;var tip:Vector2=root-direction*lerpf(18,50,p)+direction.orthogonal()*float(side)*(12+i*8)
			draw_line(root,tip,a if i%2==0 else b,3.0,true)
	draw_circle(direction*lerpf(10,70,p),5,b)

func _wounds(p:float,a:Color,b:Color)->void:
	for i in 5:
		var q:=direction*18+direction.orthogonal()*(i-2)*11
		draw_line(q-direction.rotated(-0.7)*28*p,q+direction.rotated(-0.7)*18*p,b,4.0,true)
		draw_line(q-direction.rotated(0.7)*14*p,q+direction.rotated(0.7)*12*p,a,2.0,true)

func _piercing_bolt(p:float,a:Color,b:Color)->void:
	var tip:=direction*lerpf(8,150,p);draw_line(-direction*20,tip,a,7,true);draw_line(-direction*20,tip,b,2,true)
	draw_colored_polygon(PackedVector2Array([tip,tip-direction*18+direction.orthogonal()*9,tip-direction*18-direction.orthogonal()*9]),a)
	for i in 4:draw_arc(-direction*(i*15.0),12+i*5,PI*0.5,PI*1.5,10,b,2,true)

func _sun(p:float,a:Color,b:Color,hammer:bool)->void:
	var r:=lerpf(16,72,p);draw_arc(Vector2.ZERO,r,0,TAU,48,a,4,true)
	for i in (8 if hammer else 14):draw_line(Vector2.from_angle(TAU*i/(8.0 if hammer else 14.0))*r*0.55,Vector2.from_angle(TAU*i/(8.0 if hammer else 14.0))*r*1.35,b,3,true)
	if hammer:draw_rect(Rect2(-10,-45,20,55),a);draw_rect(Rect2(-30,-48,60,20),b)

func _scythe(p:float,a:Color,b:Color)->void:
	for i in 3:draw_arc(Vector2.ZERO,38+i*13,-2.7+p*2.0,0.5+p*2.0,30,a if i%2==0 else b,5-i,true)

func _shield(p:float,a:Color,b:Color)->void:
	var d:=direction*lerpf(15,80,p);var n:=direction.orthogonal()*lerpf(18,50,p)
	draw_colored_polygon(PackedVector2Array([d+n,d+direction*22,d-n,d-direction*12]),Color(a,0.2));draw_polyline(PackedVector2Array([d+n,d+direction*22,d-n,d-direction*12,d+n]),b,4,true)

func _tethers(p:float,a:Color,b:Color)->void:
	for j in 5:
		var pts:=PackedVector2Array([Vector2.ZERO]);var ray:=Vector2.from_angle(TAU*j/5.0+p)
		for i in range(1,8):pts.append(ray*i*12+ray.orthogonal()*sin(i*1.7+p*12+j)*8)
		draw_polyline(pts,a if j%2==0 else b,3,true)

func _prism(p:float,a:Color,b:Color)->void:
	var pts:=PackedVector2Array()
	for i in 6:pts.append(Vector2.from_angle(TAU*i/6.0+p*4)*lerpf(18,45,p))
	draw_colored_polygon(pts,Color(a,0.24));draw_polyline(pts+PackedVector2Array([pts[0]]),b,4,true)
	for i in 6:draw_line(Vector2.ZERO,pts[i],Color.from_hsv(float(i)/6.0,0.6,1.0,1.0-p),2,true)

func _thorns(p:float,a:Color,b:Color)->void:
	for side in [-1.0,1.0]:
		var pts:=PackedVector2Array()
		for i in 8:pts.append(Vector2(side*i*8,-i*i*1.3*p))
		draw_polyline(pts,a,5,true)
		for i in range(2,8,2):draw_line(pts[i],pts[i]+Vector2(side*10,-10),b,3,true)

func _radiance(p:float,a:Color,b:Color)->void:
	for i in 12:
		var ang:=TAU*i/12.0;draw_line(Vector2.from_angle(ang)*12,Vector2.from_angle(ang)*lerpf(35,90,p),a if i%2==0 else b,lerpf(5,1,p),true)
	draw_circle(Vector2.ZERO,lerpf(18,5,p),b)

func _fire_cone(p:float,a:Color,b:Color)->void:
	for i in 16:
		var spread:=(float(i%7)-3.0)*0.08;var q:=direction.rotated(spread)*lerpf(15,130,p*float(i+3)/19.0)
		draw_circle(q+direction.orthogonal()*sin(i+p*20)*7,5+float(i%4),a if i%2==0 else b)

func _serpent(p:float,a:Color,b:Color)->void:
	var pts:=PackedVector2Array()
	for i in 18:pts.append(direction*i*7+direction.orthogonal()*sin(i*0.8-p*15)*13)
	draw_polyline(pts,a,8,true);draw_circle(pts[-1],9,b);draw_line(pts[-1],pts[-1]+direction*13,b,3,true)

func _web(p:float,a:Color,b:Color)->void:
	var r:=lerpf(12,70,p)
	for i in 8:draw_line(Vector2.ZERO,Vector2.from_angle(TAU*i/8.0)*r,a,2,true)
	for j in range(1,4):draw_arc(Vector2.ZERO,r*j/4.0,0,TAU,32,b,2,true)

func _pages(p:float,a:Color,b:Color)->void:
	for side in [-1.0,1.0]:
		var center:=Vector2(side*22,-8);draw_colored_polygon(PackedVector2Array([center+Vector2(0,-22),center+Vector2(side*28,-15),center+Vector2(side*26,22),center+Vector2(0,16)]),Color(a,0.3));draw_line(center+Vector2(0,-22),center+Vector2(0,16),b,3,true)
	for i in 6:draw_circle(Vector2.from_angle(TAU*i/6.0-p*4)*lerpf(18,60,p),3,a)

func _thunder(p:float,a:Color,b:Color)->void:
	draw_line(Vector2.ZERO,direction*150,Color(a,0.45),4,true)
	for i in range(1,6):
		var q:=direction*i*26;draw_circle(q,6+i*2*p,b);draw_arc(q,18*p,0,TAU,20,a,3,true)

func _gravity(p:float,a:Color,b:Color)->void:
	for i in 4:draw_arc(Vector2.ZERO,18+i*14+p*12,p*(i+1)*2,TAU*0.7+p*(i+1)*2,28,a if i%2==0 else b,4-i*0.6,true)
	for m in motes:var q:=Vector2.from_angle(float(m.angle)-p*8)*lerpf(90,10,p);draw_circle(q,float(m.size),a)

func _song(p:float,a:Color,b:Color)->void:
	for i in 4:draw_arc(Vector2.ZERO,18+i*18+p*12,-2.2,2.2,32,a if i%2==0 else b,3,true)
	for i in 5:var q:=Vector2((i-2)*18,-35-12*sin(p*10+i));draw_circle(q,5,b);draw_line(q,q+Vector2(0,18),a,3,true)

func _bloom(p:float,a:Color,b:Color)->void:
	for i in 10:var ang:=TAU*i/10.0+p;var q:=Vector2.from_angle(ang)*lerpf(8,30,p);draw_circle(q,lerpf(12,4,p),a if i%2==0 else b)
	draw_arc(Vector2.ZERO,lerpf(20,75,p),0,TAU,40,a,3,true)

func _frost(p:float,a:Color,b:Color)->void:
	for i in 12:var ang:=TAU*i/12.0;var q:=Vector2.from_angle(ang)*lerpf(15,82,p);draw_line(q-Vector2.from_angle(ang)*12,q+Vector2.from_angle(ang)*12,a,3,true);draw_line(q,q+Vector2.from_angle(ang+0.7)*8,b,2,true)

func _titan(p:float,a:Color,b:Color)->void:
	for i in 5:var x:=(i-2)*18.0;draw_line(Vector2(x,-90+40*p),Vector2(x,55),a,7,true);draw_circle(Vector2(x,55),7,b)
	draw_arc(Vector2.ZERO,45,PI,TAU,28,b,5,true)

func _wails(p:float,a:Color,b:Color)->void:
	for i in 8:
		var ray:=Vector2.from_angle(TAU*i/8.0+p);var head:=ray*lerpf(10,85,p);var pts:=PackedVector2Array()
		for j in 7:pts.append(head-ray*j*7+ray.orthogonal()*sin(j*1.4+p*18+i)*5)
		draw_polyline(pts,a if i%2==0 else b,4,true);draw_circle(head,7,a)

func _wheel(p:float,a:Color,b:Color)->void:
	var r:=48.0;draw_arc(Vector2.ZERO,r,0,TAU,48,a,6,true);draw_arc(Vector2.ZERO,20,0,TAU,30,b,4,true)
	for i in 8:var ang:=TAU*i/8.0+p*7;draw_line(Vector2.from_angle(ang)*20,Vector2.from_angle(ang)*r,a,5,true);draw_circle(Vector2.from_angle(ang)*r,5,b)

func _paradox(p:float,a:Color,b:Color)->void:
	for i in 4:draw_arc(Vector2.ZERO,18+i*14,-p*TAU*(1 if i%2==0 else -1),PI*1.35-p*TAU*(1 if i%2==0 else -1),30,a if i%2==0 else b,3,true)
	var needle:=Vector2.from_angle(p*TAU*3)*62;draw_line(-needle,needle,b,4,true)

func _momentum(p:float,a:Color,b:Color)->void:
	for i in 7:var back:=-direction*(i*14+p*10);draw_arc(back,12+i*2,-1.5,1.5,14,a if i%2==0 else b,4,true)
	draw_line(Vector2.ZERO,direction*lerpf(30,120,p),b,5,true)

func _shadow(p:float,a:Color,b:Color)->void:
	for i in 10:var q:=-direction*i*11+direction.orthogonal()*sin(i+p*15)*14;draw_circle(q,13-float(i),Color(a,0.45));draw_circle(q,3,b)

func _blood(p:float,a:Color,b:Color)->void:
	for i in 9:var q:=Vector2.from_angle(TAU*i/9.0+p*6)*lerpf(25,55,p);draw_circle(q,6,a);draw_line(q,q+Vector2(0,9),b,3,true)

func _pressure(p:float,a:Color,b:Color)->void:
	for i in 5:draw_arc(Vector2.ZERO,lerpf(80-i*10,15+i*5,p),0,TAU,36,a if i%2==0 else b,4,true)
	for i in 8:draw_line(Vector2.from_angle(TAU*i/8.0)*28,Vector2.from_angle(TAU*i/8.0)*68,b,2,true)

func _fey(p:float,a:Color,b:Color)->void:
	for i in 14:
		var q:=Vector2.from_angle(float(i)*2.4+p*(2+i%3))*lerpf(15,70,p);var c:=Color.from_hsv(fmod(float(i)*0.17,1.0),0.65,1.0,1.0-p)
		draw_circle(q,4,c);draw_line(q,q+Vector2(-7,-5),c,2,true);draw_line(q,q+Vector2(7,-5),c,2,true)

func _bramble(p:float,a:Color,b:Color)->void:
	var pts:=PackedVector2Array()
	for i in 16:pts.append(direction*i*8+direction.orthogonal()*sin(i*0.7-p*12)*11)
	draw_polyline(pts,b,12,true);draw_polyline(pts,a,5,true)
	for i in range(2,15,2):var q:=pts[i];draw_line(q,q+direction.orthogonal()*(12 if i%4==0 else -12),a,4,true)

func _hearts(p:float,a:Color,b:Color)->void:
	for i in 6:
		var q:=Vector2.from_angle(TAU*i/6.0+p)*lerpf(18,65,p);draw_line(Vector2.ZERO,q,a,2,true);draw_circle(q+Vector2(-4,-2),5,b);draw_circle(q+Vector2(4,-2),5,b);draw_colored_polygon(PackedVector2Array([q+Vector2(-9,0),q+Vector2(9,0),q+Vector2(0,12)]),b)

func _valor(p:float,a:Color,b:Color)->void:
	for i in 5:draw_arc(direction*12,18+i*17+p*8,-1.25,1.25,24,a if i%2==0 else b,4-i*0.4,true)
	draw_colored_polygon(PackedVector2Array([-direction*25+direction.orthogonal()*10,direction*12+direction.orthogonal()*22,direction*12-direction.orthogonal()*22,-direction*25-direction.orthogonal()*10]),Color(a,0.35))
