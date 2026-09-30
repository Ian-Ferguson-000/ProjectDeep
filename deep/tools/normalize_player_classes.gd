extends SceneTree

const CLASS_IDS:Array[String]=["mage","healer","phantom","tank","summoner"]
const SOURCE_FRAME_SIZE:=Vector2i(96,80)
const OUTPUT_FRAME_SIZE:=Vector2i(104,88)
const FRAME_PADDING:=Vector2i(4,4)
const OUTPUT_COLUMNS:=12

## Keeps four clean idle and run poses from the extended board, then appends
## the four canonical ability poses. Connected-component isolation removes
## fragments from neighboring generated rows before padding every frame.
func _init()->void:
	var requested:=OS.get_cmdline_user_args()
	var selected:=CLASS_IDS if requested.is_empty() else CLASS_IDS.filter(func(class_id:String)->bool:return class_id in requested)
	for class_id:String in selected:
		var locomotion_source:=Image.load_from_file("res://assets/classes/%s/slasher_sheet.png"%class_id)
		var dedicated_locomotion_path:="res://assets/classes/%s/locomotion_frames.png"%class_id
		var dedicated_locomotion:Image=Image.load_from_file(dedicated_locomotion_path) if FileAccess.file_exists(dedicated_locomotion_path) else null
		var ability_source:=Image.load_from_file("res://assets/classes/%s/sheet.png"%class_id)
		var output:=Image.create(OUTPUT_FRAME_SIZE.x*OUTPUT_COLUMNS,OUTPUT_FRAME_SIZE.y*4,false,Image.FORMAT_RGBA8);output.fill(Color.TRANSPARENT)
		for row:int in 4:
			for column:int in 8:
				var source:=locomotion_source;var source_column:=column;var source_row:=row;var source_columns:=16;var source_rows:=4
				if dedicated_locomotion!=null:
					source=dedicated_locomotion;source_column=(column%4)*2;source_row=int(column/4)*4+row;source_columns=8;source_rows=8
				var left:=roundi(float(source_column)*source.get_width()/float(source_columns));var right:=roundi(float(source_column+1)*source.get_width()/float(source_columns))
				var top:=roundi(float(source_row)*source.get_height()/float(source_rows));var bottom:=roundi(float(source_row+1)*source.get_height()/float(source_rows))
				var cell:=source.get_region(Rect2i(left,top,right-left,bottom-top));var component:=cell.get_region(_largest_component_bounds(cell))
				var scale_factor:=minf(1.0,minf(float(SOURCE_FRAME_SIZE.x)/component.get_width(),float(SOURCE_FRAME_SIZE.y)/component.get_height()))
				if scale_factor<1.0:component.resize(maxi(1,roundi(component.get_width()*scale_factor)),maxi(1,roundi(component.get_height()*scale_factor)),Image.INTERPOLATE_NEAREST)
				var destination:=Vector2i(column*OUTPUT_FRAME_SIZE.x+(OUTPUT_FRAME_SIZE.x-component.get_width())/2,row*OUTPUT_FRAME_SIZE.y+OUTPUT_FRAME_SIZE.y-component.get_height()-4)
				output.blit_rect(component,Rect2i(Vector2i.ZERO,component.get_size()),destination)
			for ability_index:int in 4:
				var source_rect:=Rect2i(Vector2i((ability_index+2)*SOURCE_FRAME_SIZE.x,row*SOURCE_FRAME_SIZE.y),SOURCE_FRAME_SIZE)
				var destination:=Vector2i((ability_index+8)*OUTPUT_FRAME_SIZE.x,row*OUTPUT_FRAME_SIZE.y)+FRAME_PADDING
				output.blit_rect(ability_source,source_rect,destination)
		output.save_png("res://assets/classes/%s/padded_sheet.png"%class_id)
	quit()

func _largest_component_bounds(image:Image)->Rect2i:
	var visited:=PackedByteArray();visited.resize(image.get_width()*image.get_height())
	var best_count:=0;var best_bounds:=Rect2i(0,0,1,1)
	for y:int in image.get_height():
		for x:int in image.get_width():
			var start_index:=y*image.get_width()+x
			if visited[start_index]!=0 or image.get_pixel(x,y).a<=0.04:continue
			var queue:Array[Vector2i]=[Vector2i(x,y)];visited[start_index]=1;var cursor:=0;var count:=0;var minimum:=Vector2i(x,y);var maximum:=minimum
			while cursor<queue.size():
				var point:=queue[cursor];cursor+=1;count+=1;minimum.x=mini(minimum.x,point.x);minimum.y=mini(minimum.y,point.y);maximum.x=maxi(maximum.x,point.x);maximum.y=maxi(maximum.y,point.y)
				for direction:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next:=point+direction
					if next.x<0 or next.y<0 or next.x>=image.get_width() or next.y>=image.get_height():continue
					var next_index:=next.y*image.get_width()+next.x
					if visited[next_index]==0 and image.get_pixelv(next).a>0.04:visited[next_index]=1;queue.append(next)
			if count>best_count:best_count=count;best_bounds=Rect2i(minimum,maximum-minimum+Vector2i.ONE)
	return best_bounds
