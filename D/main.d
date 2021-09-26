// SkiiFree'd - KATKO 2017
//=============================================================================
/*
	QUESTION
		- What if we made this into an ISOMETRIC('ish) game? 
			- It needs to be SHARPLY angled since we're travelling you know... down. 
			- Any games we can think of?
		- Monsters
		- BOUNDING COLLISION BOXES (also draw collision boxes?)

	NEW FEATURES
		- New enemies?
		*	SPIDER. YETI.  HORROR.
		- CLIFFS
		- New obsticles?
		- New... stuff?
		- WEATHER?
		- Water/ponds/RIVERS? Jump over them
 		- LAND TYPES (rare?)
				- i.e. mud trenches like a mud version of a river generation

		- NEW PARTICLE: Skii trails! <----
		- WIND. Make snow particles go the same direction!
				- give wind a direction and velocity
				- give particles a bell curve + std deviation to change from that
				- should snow ever land on the "ground" instead of the edge of the screen
					which essentially means the snow is so high up

		- Neat thing is, because snow particles are viewport position aware, they "change" 
			as you move left or right or down on the map, even though they're still just clipped
			and wrapped at the viewport boundaries.


	- POWERUPS
		- Pac-man style "ghosts run away" powerup
		- GTA style machine gun killer powerups. (spawns more enemies too?)


*/
// http://www.everything2.com/title/Skifree

import std.stdio;
import std.conv;
import std.string;
import std.format;
import std.format;
import std.random;
import std.algorithm;
import std.traits; // EnumMembers

//thread yielding?
//-------------------------------------------
import core.thread; //for yield... maybe?
extern (C) int pthread_yield(); //does this ... work? No errors yet I can't tell if it changes anything...
//------------------------------

pragma(lib, "dallegro5");

version(ALLEGRO_NO_PRAGMA_LIB)
{

}else{
	pragma(lib, "allegro");
	pragma(lib, "allegro_primitives");
	pragma(lib, "allegro_image");
	pragma(lib, "allegro_font");
	pragma(lib, "allegro_ttf");
	pragma(lib, "allegro_color");
}
import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

// Helper functions
//=============================================================================

// can't remember the best name for this.
 void clampUpper(T)(ref T val, T max)
	{
	if(val > max)
		{
		val = max;
		}
	}	

void clampLower(T)(ref T val, T min)
	{
	if(val < min)
		{
		val = min;
		}
	}	

void clampBoth(T)(ref T val, T min, T max)
	{
	if(val < min)
		{
		val = min;
		}
	if(val > max)
		{
		val = max;
		}
	}	


// CONSTANTS
//=============================================================================
struct globals_t
	{
	ALLEGRO_FONT* 			font;
	ALLEGRO_BITMAP* 		snow_bmp;
	ALLEGRO_BITMAP* 		snowflake_bmp;
	ALLEGRO_BITMAP* 		bmp;
	immutable float JUMP_VELOCITY = 2.2F; 
	immutable uint NUM_SNOW_PARTICLES = 50; //per viewport

	//world dimensions
	immutable float maximum_x = 2000F; 	
	immutable float maximum_y = 20_000F; 
	immutable float maximum_z = 100F; 	

	//player constants
	immutable float SPEED_FACTOR = 3.0F; //scales UP/down all speeds.
	immutable float speed_change_rate = .1F * SPEED_FACTOR; 	
	immutable float speed_maximum	  =  1.3F * SPEED_FACTOR; 	
	immutable float player_jump_velocity = 10.0F; 	

	int SCREEN_W = 1200;
	int SCREEN_H = 600;

	immutable float bullet_velocity = 7.5f;
	
	ALLEGRO_COLOR snow_color;

	}

globals_t g;

struct bullet_handler
	{
	bullet_t[] data;
	
	void add(bullet_t b)
		{
		data ~= b;
		}
	
	void on_tick()
		{
		foreach (b; data) 
			{
			b.on_tick();
			}
			
		//prune ready-to-delete entries
		for (size_t i = data.length ; i-- > 0 ; )
			{
			if(data[i].delete_me)data = data.remove(i); continue;
			}//https://forum.dlang.org/post/sagacsjdtwzankyvclxn@forum.dlang.org
		}
	
	void draw(viewport_t v)
		{
		foreach (b; data) 
			{
			b.draw(v);
			}
		}
	
//	void cleanUp() //are we even calling this.
	//	{
//		foreach (b; data) 
	//		{
		//	if(b.x < 0){ b.delete_me = true;} //delete
			//if(b.y < 0){ b.delete_me = true;}
			//}
		//}
	}

enum 
	{
	DIR_SINGLE_FRAME	= -3, //note
	DIR_FULL_LEFT 		= -3, //note (wish I remembered why these are the same other than just writing 'note')
	DIR_FAR_ANGLE_LEFT 	= -2,
	DIR_ANGLE_LEFT 		= -1,
	DIR_DOWN 			= 0,
	DIR_ANGLE_RIGHT 	= 1,
	DIR_FAR_ANGLE_RIGHT = 2,
	DIR_FULL_RIGHT 		= 3,
	}

immutable float [7] v_speeds = 
	[
	0, 
	0.1F/4, 
	0.1F/2, 
	0.1F,
	0.1F/2,
	0.1F/4,
	0
	];

immutable float [7] h_speeds = 
	[
	-0.1F, 
	-0.1F/2, 
	-0.1F/4, 
	0,
	0.1F/4,
	0.1F/2,
	0.1F
	];

immutable float [7] v_to_h_conversion = 
	[
	-1.0, 
	-0.8, 
	-0.6, 
	 0.0,
	 0.6,
	 0.8,
	 1.0
	];

//GLOBALS
//=============================================================================

// DEBUG
immutable bool DEBUG_DRAW_BOXES = true;
immutable bool DEBUG_NO_BACKGROUND = true;




ALLEGRO_CONFIG* 		cfg;  //whats this used for?
ALLEGRO_DISPLAY* 		al_display;
ALLEGRO_EVENT_QUEUE* 	queue;


animation_t player_anim;
animation_t monster_anim;
animation_t tree_anim;
animation_t jump_anim;
animation_t bullet_anim;

keyset_t [2] player_controls;
world_t world;
viewport_t [2] viewports;
ALLEGRO_TIMER *fps_timer;

int mouse_x = 0; //cached, obviously. for helper routines.
int mouse_y = 0;
int mouse_lmb = 0;

xy_pair target;

struct xy_pair
	{
	int x;
	int y;
	
	this(int _x, int _y)
		{
		x = _x;
		y = _y;
		}
	}

display_t display;

// Is there any way we can have global variables in a NAMESPACE (use a module?)
// Or is the single dereference NOT a big deal to pass tbe "globals struct"
// to every main function...

struct statistics_t
	{
	ulong number_of_drawn_particles;
	ulong number_of_drawn_objects;
	ulong number_of_drawn_background_tiles;
	ulong fps;
	ulong frames_passed;
	}

statistics_t stats;

//=============================================================================

class animation_t
	{
	bool has_loaded_a_frame;
	ALLEGRO_BITMAP *[] frames;
	string [] names;
	
	int get_width()
		{
		assert(has_loaded_a_frame, "Did you remember to ADD a frame before calling get_width()?");
		return al_get_bitmap_width(frames[0]);
		}
		
	int get_height()
		{
		assert(has_loaded_a_frame, "Did you remember to ADD a frame before calling get_height()?");
		return al_get_bitmap_height(frames[0]);
		}

	void load_extra_frame(string path)
		{
		ALLEGRO_BITMAP *extra_frame = al_load_bitmap( toStringz(path));
		assert(extra_frame != null, "fuck");
		
		frames ~= extra_frame;
		//names = to!string(); 
		names ~= "OOPS."; //filler, what happens if not unique? Return first result?
		has_loaded_a_frame = true;
		}
		
	void load_extra_frame_mirrored(string path)
		{
		ALLEGRO_BITMAP *original_frame = al_load_bitmap( toStringz(path));
		ALLEGRO_BITMAP *extra_frame = 
			al_create_bitmap(
				al_get_bitmap_width(original_frame), 
				al_get_bitmap_height(original_frame));
		
		al_set_target_bitmap(extra_frame);
		al_draw_bitmap(original_frame, 0, 0, ALLEGRO_FLIP_HORIZONTAL);
		al_set_target_bitmap(al_get_backbuffer(al_display)); //set back to original.
		
		frames ~= extra_frame;
		//names = to!string(); 
		names ~= "OOPS."; //filler, what happens if not unique? Return first result?
		has_loaded_a_frame = true;
		}

	void load_extra_frame(string path, string name)
		{
		ALLEGRO_BITMAP *extra_frame = al_load_bitmap( toStringz(path));
		frames ~= extra_frame;
		names ~= name;
		has_loaded_a_frame = true;
		}
		
	ALLEGRO_BITMAP* get_frame_by_number(int i) //TODO
		{
		ALLEGRO_BITMAP* x;
		return x;
		}
	ALLEGRO_BITMAP* get_frame_by_name(string name) //TODO
		{
		ALLEGRO_BITMAP* x;
		return x;
		}
	
	void draw(int frame, float x, float y)
		{
		stats.number_of_drawn_objects++;
		al_draw_bitmap(frames[frame], x, y, 0);
		}

	void draw_rotated(int frame, float x, float y, float angle)
		{
		stats.number_of_drawn_objects++;

		al_draw_rotated_bitmap(frames[frame], 
			al_get_bitmap_width(frames[frame])/2, 
			al_get_bitmap_height(frames[frame])/2, 
			x, 
			y, 
			angle, 
			0);
		}

	void draw_centered(int frame, float x, float y)
		{
		stats.number_of_drawn_objects++;
		al_draw_bitmap(
			frames[frame], 
			to!(int)(x) - get_width() / 2,
			to!(int)(y) - get_height() / 2, 
			0);
			
//		draw_target_dot (x, y); 
//		draw_target_dot (x - get_width()/2, y - get_height()/2); 
		
		static if (false) // Draw bordering dots
			{
			//top left
			draw_target_dot(  
				to!(int)(x - get_width()/2), 
				to!(int)(y - get_height()/2));	
			//bottom left
			draw_target_dot(  
				to!(int)(x - get_width()/2), 
				to!(int)(y - get_height()/2 + get_height()));
			//top right
			draw_target_dot(  
				to!(int)(x - get_width()/2 + get_width()), 
				to!(int)(y - get_height()/2));
			//bottom right
			draw_target_dot(  
				to!(int)(x - get_width()/2 + get_width()), 
				to!(int)(y - get_height()/2 + get_height()));
			}
		}
		
	void empty(){}
	}
	
void load_resources()	
	{
	player_anim = new animation_t;
	monster_anim = new animation_t;
	tree_anim = new animation_t;
	jump_anim = new animation_t;
	bullet_anim = new animation_t;
	
	player_anim	.load_extra_frame_mirrored("./data/skier_01.png");
	player_anim	.load_extra_frame_mirrored("./data/skier_02.png");
	player_anim	.load_extra_frame_mirrored("./data/skier_03.png");
	player_anim	.load_extra_frame("./data/skier_04.png");
	player_anim	.load_extra_frame("./data/skier_03.png");
	player_anim	.load_extra_frame("./data/skier_02.png");
	player_anim	.load_extra_frame("./data/skier_01.png");

	monster_anim.load_extra_frame("./data/yeti.png");
	tree_anim	.load_extra_frame("./data/tree.png");
	jump_anim	.load_extra_frame("./data/mysha.pcx");
	
	bullet_anim.load_extra_frame("./data/bullet.png");
	}

//DEFINITELY want this to be a class / reference type!
class object_t //could we use a drawable_object whereas object_t has re-usable functionality for a camera_t?
	{
	public:
	
	bool		delete_me = false;
	
	float 		x, y, z; //objects are centered at X/Y (not top-left) so we can easily follow other objects.
	float		x_vel, y_vel, z_vel; //note Z is used for jumps.

	int direction; // see enum
//	float		angle; // instead of x_vel, y_vel?
//	float		vel;
	float		w, h;
	int			w2, h2; //cached half width/height
	
	bool trips_you;
	bool slows_you_down;
	bool is_following_another_object; 
	object_t object_to_follow; 

	void set_width(float _w)
		{
		w = _w;
		w2 = to!(int)(w/2);
		}
		
	void set_height(float _h)
		{
		h = _h;
		h = to!(int)(h/2);
		}

	this()
		{			
		direction = DIR_DOWN; // -3, -2, -1, 0, 1, 2, 3
		x = 0;
		y = 0;
		z = 0;
		x_vel = 0;
		y_vel = 0;
		z_vel = 0;
		// I thought this shit was AUTO INITALIZED?
			
		trips_you = false;
		slows_you_down = false;
		is_following_another_object = false;
		}
		
	void follow_object(object_t obj)
		{
		is_following_another_object = true;
		object_to_follow = obj;
		}
	
	// INPUTS (do we support mouse input?)
	// ------------------------------------------
	void up(){}
	void down(){}
	void left(){}
	void right(){}
	void action(){} // ala space. for monster this would be EAT MWAHAHA. (or is that automatic?) LET HIM EAT OTHER PEOPLE AND STUFF TOO.
	void click_at(float relative_x, float relative_y){} //maybe? relative to object coordinate.
	
	// EVENTS
	// ------------------------------------------
	void on_tick()
		{
		if(is_following_another_object)
			{
			x = object_to_follow.x;
			y = object_to_follow.y;
			}
		x += x_vel;
		y += y_vel;
		}

	void on_collision(object_t other_obj)
		{
		}	
	}
	
class camera_t : object_t 
	{
	// simply uses the follow object routines in object_t!
	}

class drawable_object_t : object_t /// drawable AND collidable
	{
	// Collision box. e.g. for trees, it's the stump, not the whole sprite.
	int	bounding_x;
	int	bounding_y;
	int	bounding_w;
	int	bounding_h;

	this()	
		{
		bounding_x = 0;
		bounding_y = 0;
		bounding_w = 16;
		bounding_h = 16;

		x = -11; //error data for testing
		y = -110;

		//writeln("[drawable_object_t] constructor called.");
		}
	
	void setup_dimensions(animation_t anim)
		{
		set_width(anim.get_width());
		set_height(anim.get_height());
		bounding_w = anim.get_width();
		bounding_h = anim.get_height();
		bounding_x = -bounding_w/2;
		bounding_y = -bounding_h/2;
		}
	
	bool is_colliding_with(drawable_object_t obj)
		{
		assert(this != obj);	

		auto x1 = x + bounding_x; //oh my fucking GOD. why was this BOUNDING_X?
		auto y1 = y + bounding_y; //note bounding_x/y are negative numbers above.
		auto w1 = w;
		auto h1 = h;
		
		auto x2 = obj.x + obj.bounding_x; 
		auto y2 = obj.y + obj.bounding_y; 
		auto w2 = obj.w;
		auto h2 = obj.h;
		
		writeln("x1: ", x1, " y1: ", y1, " w1: ", w1, " h1: ", h1, " type: ", this);
		writeln("x2: ", x2, " y2: ", y2, " w2: ", w2, " h2: ", h2, " type: ", obj);
		
		if( x1      < x2 + w2 &&
			x1 + w1 > x2      &&
			y1      < y2 + h2 &&
			y1 + h1 > y2)
			{
			writeln("MATCH");
			return true;
			}
		/* from https://wiki.allegro.cc/index.php?title=Bounding_Box 
		 * also dead link
		*/	
		//https://developer.mozilla.org/en-US/docs/Games/Techniques/2D_collision_detection
			
		// this can't be right with four OR'd elements.
/*		if(	x1 > x2 + w2 - 1 	|| 
			y1 > y2 + h2 - 1 	||
			x2 > x1 + w1 - 1	||
			y2 > y1 + w1 - 1) saved to analyze later 
			{
			return false;
			}*/
		return false;
		}
	
	animation_t animation;
	//int frame; for animated pieces
	//float frame_delay; //number of logic frames per increment 
	//enum direction? // dir=0 for buildings. other directions... how many did skiifree have?
	// this many:
	//  down, 
	//	down left, down left left, left
	//  down right, down right right, right
	void draw_bounding_box(viewport_t v)
		{
		ALLEGRO_COLOR color = al_map_rgba(255,0,0, 255);
		ALLEGRO_COLOR color2 = al_map_rgba(255,0,0, 64);
		
		xy_pair top_left = xy_pair (
			to!(int)(x) + bounding_x - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y - to!(int)(v.offset_y) + v.y);
		xy_pair top_right = xy_pair (
			to!(int)(x) + bounding_x + bounding_w - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y - to!(int)(v.offset_y) + v.y);
		xy_pair bottom_left = xy_pair (
			to!(int)(x) + bounding_x - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y + bounding_h - to!(int)(v.offset_y) + v.y);
		xy_pair bottom_right = xy_pair (
			to!(int)(x) + bounding_x + bounding_w - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y + bounding_h - to!(int)(v.offset_y) + v.y);

		al_draw_rectangle(
			top_left.x, 
			top_left.y,
			bottom_right.x, 
			bottom_right.y,
			color, 
			1.0F);

		draw_target_dot(top_left);
		draw_target_dot(top_right);
		draw_target_dot(bottom_left);
		draw_target_dot(bottom_right);
		
		//draw centerline.
		//horiztonal
		al_draw_line(
			top_left.x, 
			(top_left.y + bottom_right.y)/2,  //center 
			bottom_right.x, 
			(top_left.y + bottom_right.y)/2,  //center 
			color2, 
			1);

		//vertical
		al_draw_line(
			(top_left.x + bottom_right.x)/2,  //center
			top_left.y,
			(top_left.x + bottom_right.x)/2,  //center 
			bottom_right.y,
			color2, 
			1);
		}

	// Theoretical (if correct) dimensions of where the sprite should be,
	// including a center line. 
	void draw_sprite_box(viewport_t v)
		{
		ALLEGRO_COLOR color = al_map_rgb(0,255,0);
		ALLEGRO_COLOR color2 = al_map_rgba(0,255,0,64);
		
		xy_pair top_left = xy_pair (
			to!(int)(x) + bounding_x - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y - to!(int)(v.offset_y) + v.y);
		xy_pair top_right = xy_pair (
			to!(int)(x) + bounding_x + bounding_w - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y - to!(int)(v.offset_y) + v.y);
		xy_pair bottom_left = xy_pair (
			to!(int)(x) + bounding_x - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y + bounding_h - to!(int)(v.offset_y) + v.y);
		xy_pair bottom_right = xy_pair (
			to!(int)(x) + bounding_x + bounding_w - to!(int)(v.offset_x) + v.x, 
			to!(int)(y) + bounding_y + bounding_h - to!(int)(v.offset_y) + v.y); 

		al_draw_rectangle(
			top_left.x, 
			top_left.y,
			bottom_right.x, 
			bottom_right.y,
			color, 
			1.0F);

		draw_target_dot(top_left);
		draw_target_dot(top_right);
		draw_target_dot(bottom_left);
		draw_target_dot(bottom_right);
		
		//draw centerline.
		//horiztonal
		al_draw_line(
			top_left.x, 
			(top_left.y + bottom_right.y)/2,  //center 
			bottom_right.x, 
			(top_left.y + bottom_right.y)/2,  //center 
			color2, 
			1);

		//vertical
		al_draw_line(
			(top_left.x + bottom_right.x)/2,  //center
			top_left.y,
			(top_left.x + bottom_right.x)/2,  //center 
			bottom_right.y,
			color2, 
			1);
		}

	void set_animation(animation_t anim)
		{
		assert(anim !is null, "You passed a NULL animation to set_animation in drawable_object_t!");
		animation = anim;
		
		setup_dimensions(anim);		
		}

	void draw(viewport_t viewport) /// Drawn centered
		{		
		auto v = viewport;
		
		//WARNING: CONFIRM THESE.
		if(x + w/2 + w - v.offset_x < 0)return;
		if(y + h/2 + h - v.offset_y < 0)return;
		if(x - w/2     - v.offset_x > g.SCREEN_W)return;	
		if(y - h/2     - v.offset_y > g.SCREEN_H)return;	
		
//		al_draw_circle(0, 0, 1, al_map_rgb(0,0,0));
		assert(animation !is null, "DID YOU REMEMBER TO SET THE ANIMATION for this object before calling it and blowing it up?");

		animation.draw_centered(
			direction + 3, //frame, NOTE, hardcoded direction size! 
			x - v.offset_x + v.x, 
			y - v.offset_y + v.y); //clipping not used yet. just pass along the viewport again?

		static if(DEBUG_DRAW_BOXES)
			{
			draw_bounding_box(v);
			}
		}
	}


class bullet_t : drawable_object_t
	{
		/*  this one works, however the default behavior seems to be all i need at the moment.
	import std.array : appender; 
    override string toString() const pure @safe
    {
        // Typical implementation to minimize overhead
        // of constructing string
        auto app = appender!string();
        app ~= "bullet_t_yo";
        return app.data;
    }   	
    */	
		
	/*
	// this does not appear to work
	// https://wiki.dlang.org/Defining_custom_print_format_specifiers
	// This method now takes a delegate to send data to.
    void toString(scope void delegate(const(char)[]) sink) const
    {
        // So you can write your data piecemeal to its
        // destination, without having to construct a
        // string and then return it.
        sink("bullet_t");
        // Look, ma! No string allocations needed!
    }
    */
    	
	float a = 0; /// angle
	this()
		{
		x = -1;
		y = -10;
		direction = DIR_SINGLE_FRAME;
		trips_you = false;
		set_animation(bullet_anim); // WARNING, using global interfaced bullet_anim
		writeln("[bullet_t] constructor called.");
		}



// FLAW. this copy's drawable object but we need only change one line or so for ROTATIONS.
// either add it to main class or figure out how to split the changed parts only		
	override void draw(viewport_t viewport)
		{		
		auto v = viewport;
		
		//WARNING: CONFIRM THESE.
		if(x + w/2 + w - v.offset_x < 0)return;
		if(y + h/2 + h - v.offset_y < 0)return;
		if(x - w/2     - v.offset_x > g.SCREEN_W)return;	
		if(y - h/2     - v.offset_y > g.SCREEN_H)return;	
		
//		al_draw_circle(0, 0, 1, al_map_rgb(0,0,0));
		assert(animation !is null, "DID YOU REMEMBER TO SET THE ANIMATION for this object before calling it and blowing it up?");

		animation.draw_rotated(
			direction + 3, 
			x - v.offset_x + v.x, 
			y - v.offset_y + v.y,
			a);
			
		//draw_bounding_box(v);
		}


	override void on_tick()
		{
		if(x < 0)delete_me = true;
		if(y < 0)delete_me = true;
		if(x > g.maximum_x)delete_me = true;
		if(y > g.maximum_y)delete_me = true;
			
		// shouldn't need the first clause because this is now only in bullet_t not drawable object.
		// though something may be needed when we put it back in
		if( this != world.objects[1] &&
			is_colliding_with( world.objects[1]) ) //hardcoded to player 2
			{
			auto o = world.objects[1];
			writeln("BOOM! @ x:", x, " y: ", y, " w: ", w, " h: ", h);
			writeln("      @ x:", o.x, " y: ", o.y, " w: ", o.w, " h: ", o.h);
			writeln();
			
			delete_me = true;
			}

		super.on_tick();
		}

	}
	

class large_tree_t : drawable_object_t
	{
	this()
		{
		direction = DIR_SINGLE_FRAME;
		trips_you = true;
		set_animation(tree_anim); // WARNING, using global interfaced tree_anim
	//	writeln("[large_tree_t] constructor called.");
		}
	}

class small_tree_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		// TODO
		}
	}

class dead_tree_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		}
	}

class rock_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		}
	}

class large_rough_patch_t : drawable_object_t //slows you down.
	{
	this()
		{
		slows_you_down = true;
		}
	}

class small_rough_patch_t : drawable_object_t //slows you down.
	{
	this()
		{
		slows_you_down = true;
		}
	}
	
class sign_t : drawable_object_t
	{
	this()
		{
		trips_you = true;
		}
	}

class lift_stand_t : drawable_object_t //the building
	{
	this()
		{
		trips_you = true;
		}
	}

class lift_chair_t : drawable_object_t
	{
	this()
		{
		}
	}

class tree_stump : drawable_object_t 
	{
	this()
		{
		trips_you = true; //fuck you. ;)
		}
	}

class jump_t : drawable_object_t
	{
	// is a jump bool? OR, an event method!
	// OMG, we could use this method to send ANY OBJECT FLYING, MWAHAHA.
	override void on_collision(object_t other_obj) // I FREAKING LOVE EXPLICIT OVERRIDES.
		{
		auto o = other_obj;
		o.z_vel += g.JUMP_VELOCITY;
		}
	}
	
// are we using a TEXTURED particle system for snow, or a PIXEL/opengl primitive one?
// do we want this to be for all particles or just snow
struct particle
	{
	float x;
	float y;
	float xv; //not polar notation so we can quickly add without using sin/cos
	float yv;
//	ALLEGRO_BITMAP bmp; 
	} // using a handler and not an internal on_tick so we ddon't incur a function
	// call for every single update, as well as the ability to operate on multiple
	// particles at a time (MMX/AVX/etc)
	
struct snow_t
	{
	particle[] data;
	ALLEGRO_COLOR c;
	
	void add(float x, float y, float xv, float yv)
		{
//		writeln("x: ", x, " y: ", y, " ---- ");
	//	writeln("vx: ", xv, " vy: ", yv, "  ");

		particle p;
			p.x = x;
			p.y = y;
			p.xv = xv;
			p.yv = yv;
		data ~= p;
		}
	
	void draw(viewport_t v)
		{
		stats.number_of_drawn_particles += data.length; //note, we may have multiple viewports! So we add this, not set it to length. And reset every frame.
		// consider locking bitmap
		foreach(p; data)
			{
//			writeln("p.x: ", p.x, " p.y: ", p.y, " ---- ");
// al_draw_rectangle(float x1, float y1, float x2, float y2,ALLEGRO_COLOR color, float thickness);
			//al_draw_pixel(p.x - v.offset_x, p.y - v.offset_y, al_map_rgb(1,1,0));
			int radius = 3;
			al_draw_filled_circle(
				p.x - v.offset_x,  // why DOESNT this need + v.x?
				p.y - v.offset_y,  // why DOESNT this need + v.y?
				radius, 
				al_map_rgba_f(.9,.9,.9,.9));
			//al_draw_bitmap(g.snowflake_bmp, p.x - v.offset_x, p.y - v.offset_y, 0);
			// al_draw_pixel vs al_put_pixel (no blending) vs etc.
			// https://www.allegro.cc/manual/5/al_put_blended_pixel ?
			}
		}
	

	// NOTE, this is called BY VIEWPORTS (who own it)
	// not the normal GFX pathway hence the viewport name prefix.
	// Each viewport manages its own set of snow particles so they can be wrapped 
	// at the viewport boundaries per viewport and no particles are accessed by
	// the other viewport so it's just two simple arrays instead of sorting / booleans / etc
	// to tell them apart. Since they're high-count particles they need to be as simple as possible.
	void on_viewport_tick(viewport_t v)
		{
		foreach(ref p; data)
			{
//			writeln("p.x: ", p.x, " p.y: ", p.y, "  before");
	//		writeln("p.xv: ", p.xv, " p.yv: ", p.yv, "  before");
			p.x += p.xv;
	 		p.y += p.yv;
	 			 		
	 		//viewport wrapping  ("clamp wrap"? tile clamp?)
	 		if(p.x < 0 + v.offset_x + v.x) p.x += v.width;
	 		if(p.y < 0 + v.offset_y + v.y) p.y += v.height;
	 		if(p.x > v.width  + v.offset_x + v.x) p.x -= v.width;
	 		if(p.y > v.height + v.offset_y + v.y) p.y -= v.height;
	 		
		//	writeln("p.x: ", p.x, " p.y: ", p.y, "  after");
			}
		}
	}
	
class projectile_t
	{
	animation_t sprite;
	int damage;
	int speed;
	}
	
class weapon_t
	{
	bool has_shotgun_reload=false; // likely not needed.
	int starting_ammo;
	int max_ammo;
	float fire_rate; // or cooldown?
	float recoil;
	float random_spread_accuracy;
	int fire_count_per_trigger;
	bool is_auto_fire;
	bool is_burst_fire;
	int burst_amount;

	projectile_t projectile;
	}

class weapon_instance_t
	{
	weapon_t w;
	int ammo;
	float cooldown; //till next shot in milliseconds
	}
	
class pickup_t {} /// item to be picked up
class ammo_crate : pickup_t
	{
	animation_t sprite;
	weapon_t ammo_for_type;
	}

class ai_state_t{}

class ai_t
	{
	ai_state_t [] states;
	ai_state_t current_state;
	}

class monster_ai_t
	{
	//"run at assholes"
	}

/// Things that can Hurt (TM) you. e.g. Lionel Richie albums.
class monster_t : drawable_object_t
	{
	ai_t ai;
	// yeti:
	// standing, alerted, walking, running, sprint-at-player, eating-player
	// , enraged, dying, corpse
	// eat animals?

	this()
		{
		direction = DIR_SINGLE_FRAME;
		trips_you = true;
		set_animation(monster_anim); // WARNING, using global interfaced tree_anim
	//	writeln("[large_tree_t] constructor called.");
		}
	
	override void on_tick()
		{
		immutable float SPEED = 1;
		auto t = world.objects[0]; //target
		
		import std.math : abs;
		if( abs(x - t.x) < 200 &&  // if within range, run at player.
			abs(y - t.y) < 200 )
			{
			if(x < t.x) x+= SPEED;
			if(x > t.x) x-= SPEED;
			if(y < t.y) y+= SPEED;
			if(y > t.y) y-= SPEED;
			}
		
		//run torward assholes
		// need a find_player method. (what about multiple players?)
		// Do we also need an A* algorithm (or something more basic)
		// for navigating around objects when stuck?
		// How do we get the monster to zig-zag like in the game?
		}
	
	void scream()
		{
		}
	
	override void on_collision(object_t other_obj) 
		{
		if(auto p = cast(skier_t) other_obj)
			{
			// I'M GONNA EAT YOU, BUB.
			}		
		}
	}
	

class yeti_t : monster_t {} 

class spider_yeti_t : yeti_t {}

class ufo_t : monster_t {} /// beams you up

class evil_skiier : monster_t {} // unarmed/knife. uzi. rocket launchers
 // NAZIS SKIIERS?!?!?
 // Are we... FLEEING A NAZI CAMP?!
 // NAZI YETIS?!

class moose_t : monster_t {}
class wolf_t : monster_t {}
class rabbit_t : monster_t {}
class fox_t : monster_t {}





/// Player class
class skier_t : drawable_object_t
	{
	bool is_jumping;
	bool is_grounded;

	this(){}
	this(int x, int y)
		{
		this.x = x; 
		this.y = y;
		writeln("[skier_t] constructor called.");
		/*
		set_width(player_anim.get_width());
		set_height(player_anim.get_height());
		bounding_w = player_anim.get_width();
		bounding_h = player_anim.get_height();
		bounding_x = -bounding_w/2;
		bounding_y = -bounding_h/2;*/
		}
	
	override void up()
			{
			writeln(" - [skier_t] up() recieved.");
			//y_vel -= speed_change_rate;
			//if(y_vel < 0)y_vel = 0;		
			}

	override void down()
			{
			writeln(" - [skier_t] down() recieved.");
			direction=0;
			//y_vel += speed_change_rate;
			//if(y_vel > speed_maximum)y_vel = speed_maximum;		
			}

	override void left()
			{
			writeln(" - [skier_t] left() recieved.");
			direction--;
			if(direction < -3)direction = -3;
			//x_vel -= speed_change_rate;
			//if(x_vel < -speed_maximum)x_vel = -speed_maximum;		
			}

	override void right()
			{
			writeln(" - [skier_t] right() recieved.");
			direction++;
			if(direction > 3)direction = 3;
			//x_vel += speed_change_rate;
			//if(x_vel > speed_maximum)x_vel = speed_maximum;		
			}

	override void action()
			{
			writeln(" - [skier_t] action() recieved.");
			if(is_grounded)
				{
				is_jumping = true; //needed?
				z_vel += g.player_jump_velocity;
				}
			}

	override void on_tick()
		{
//		writeln("Direction[", direction,"]");
//		x_vel += h_speeds[direction+3];

// FIX ME <-----------

		y_vel += v_speeds[direction+3];
		x_vel += y_vel*v_to_h_conversion[direction+3]*.05;
	
		if(y_vel > 0)y_vel -= 0.01F;
		if(x_vel > 0)x_vel -= 0.08F;
		if(x_vel < 0)x_vel += 0.08F;
	
		x += x_vel;
		y += y_vel;
		z += z_vel;

		// Speed boundaries
		x_vel.clampBoth(-g.speed_maximum, g.speed_maximum);
		y_vel.clampBoth(-g.speed_maximum, g.speed_maximum);
		z_vel.clampBoth(-g.speed_maximum, g.speed_maximum);
/*		if(x_vel > g.speed_maximum)x_vel = g.speed_maximum;
		if(y_vel > g.speed_maximum)y_vel = g.speed_maximum;
		if(z_vel > g.speed_maximum)z_vel = g.speed_maximum;
		if(x_vel < -g.speed_maximum)x_vel = -g.speed_maximum;
		if(y_vel < -g.speed_maximum)y_vel = -g.speed_maximum;
		if(z_vel < -g.speed_maximum)z_vel = -g.speed_maximum;
*/
		// Map boundaries
		if(x < 0){x_vel = 0; x = 0;}
		if(y < 0){y_vel = 0; y = 0;}
		if(z < 0){z_vel = 0; z = 0; is_grounded = true;}
		if(x >= g.maximum_x){x_vel = 0; x = g.maximum_x-1;}
		if(y >= g.maximum_y){y_vel = 0; y = g.maximum_y-1;}
		if(x >= g.maximum_z){z_vel = 0; z = g.maximum_z-1;}
		//writefln("[%f, %f, %f]-v[%f, %f, %f]", x, y, z, x_vel, y_vel, z_vel);
		
		foreach(o; world.objects)
			{
			if(auto p = cast(skier_t) o)
				{ // https://forum.dlang.org/thread/mailman.135.1328728747.20196.digitalmars-d-learn@puremagic.com
				  // if not null, it's a pointer to a skier object

				// is fellow player object
				}else{
				// is something else


				//TODO use proper bounding box distances.
				int r = 6; //radius/distance
				if(
					o.x >= this.x - r &&
					o.y >= this.y - r &&
					o.x <= this.x + r &&
					o.y <= this.y + r)
					{
					writeln("OH SNAP-- I just hit a [", o.toString(), "]");
					}
				}

			}
		}
	}
	
class viewport_t
	{
	// Screen coordinates
	int x;
	int y;
	int width;
	int height;
	
	// Camera position
	float offset_x;
	float offset_y;

	snow_t snow;
	}

class world_t
	{			
	bullet_handler bullet_h; //cleanme
	drawable_object_t [] objects; //should be drawable_object_t?
	// monster_t [] monsters; // or combine with objects? tradeoffs. 
	// - DRAW ORDER for one! (keep monsters behind trees, UFOs last and on top)
	// - collision only between things that collide (tree only searches against players. not against tree list, monster list?, etc)

	void draw_background(viewport_t v)
		{
		//texture width/height alias
		int tw = al_get_bitmap_width  (g.snow_bmp);
		int th = al_get_bitmap_height (g.snow_bmp);			
		int i = 0;
		int j = 0;
		while(i*tw < v.width*2 + v.offset_x) //is this the RIGHT?
			{
			j=0;
			while(j*th < v.height*2 + v.offset_y) //is this the RIGHT?
				{
				al_draw_bitmap(
					g.snow_bmp, 
					0 + v.x - v.offset_x - tw/2 + tw*i, 
					0 + v.y - v.offset_y - th/2 + th*j, 
					0);
				stats.number_of_drawn_background_tiles++;
				j++;
				}
			i++;
			}
		}

	// Call this ONCE (or every time new objects appear)
	// Or should we just have different lists for different objects? (so all trees are inherently 
	// on a different z-layer from players, etc.)
	void sort_objects_list() //Sorts ALL BUT the first two objects? how?
		{ //easiest way is to simply call before adding the players...
			// or, set the players to the MOST negative Y position until after sorting.
			// WE COULD EVEN STORE THE VALUES TEMPORARILY!
		// WARNING: ASsumes players 1 and 2 EXIST and are first already.
		immutable float temp_p0_y = objects[0].y;
		immutable float temp_p1_y = objects[1].y;
		objects[0].y = -1000;
		objects[1].y =  -900;
		
		alias comparison = (o1, o2) => o1.y < o2.y; //should be ordered ascending, ala [1,2,3,4]
		objects.sort!(comparison); //COULD THIS BREAK in a way we don't anticipate?
		// as long as trees are AFTER these objects, and 
		
		objects[0].y = temp_p0_y;
		objects[1].y = temp_p1_y;		
		}

	void populate_with_trees()
		{
		immutable int number_of_trees = 1000;
		
		for(int i = 0; i < number_of_trees; i++)
			{
			large_tree_t tree = new large_tree_t;
			tree.x = uniform(0, g.maximum_x);
			tree.y = uniform(0, g.maximum_y);
		
			objects ~= tree;
			}
		}
 	
	void populate_with_monsters()
		{
		immutable int number_of_monsters = 100;
		
		for(int i = 0; i < number_of_monsters; i++)
			{
			monster_t m = new monster_t;
			m.x = uniform(0, g.maximum_x);
			m.y = uniform(0, g.maximum_y);
		
			objects ~= m;
			}
		}

	void draw(viewport_t v)
		{
		static if(!DEBUG_NO_BACKGROUND)draw_background(v);
		foreach(o; objects)
			{
			o.draw(v);
			}
			
		bullet_h.draw(v);
		
		if(v == viewports[0]) //omfg kill me now.
			{
			viewports[0].snow.draw(viewports[0]); //TODO clean API
			}else{
			viewports[1].snow.draw(viewports[1]);
			}
		}

	void logic()
		{
		foreach(o; objects)
			{
			o.on_tick();
			// since there are far fewer players than everything else, lets do the collision checking in the player objects.
			}
		bullet_h.on_tick();
		viewports[0].snow.on_viewport_tick(viewports[0]);
		viewports[1].snow.on_viewport_tick(viewports[1]);
		}
	}

//https://www.allegro.cc/manual/5/keyboard.html
//	(instead of individual KEYS touching ANY OBJECT METHOD. Because what if we 
// 		change objects? We have to FIND all keys associated with that object and 
// 		change them.)
alias ALLEGRO_KEY = ubyte;
struct keyset_t
		{
		object_t obj;
		ALLEGRO_KEY [ __traits(allMembers, keys_label).length] key;
		// If we support MOUSE clicks, we could simply attach a MOUSE in here 
		// and have it forward to the object's click_on() method.
		// But again, that kills the idea of multiplayer.
		}
		
enum keys_label
	{
	ERROR = 0,
	UP_KEY,
	DOWN_KEY,
	LEFT_KEY,
	RIGHT_KEY,
	FIRE_UP_KEY,
	FIRE_DOWN_KEY,
	FIRE_LEFT_KEY,
	FIRE_RIGHT_KEY,
	ACTION_KEY
	}

bool initialize()
	{
	if (!al_init())
		{
		auto ver 		= al_get_allegro_version();
		auto major 		= ver >> 24;
		auto minor 		= (ver >> 16) & 255;
		auto revision 	= (ver >> 8) & 255;
		auto release 	= ver & 255;

		writefln(
"The system Allegro version (%s.%s.%s.%s) does not match the version of this binding (%s.%s.%s.%s)",
			major, minor, revision, release,
			ALLEGRO_VERSION, ALLEGRO_SUB_VERSION, ALLEGRO_WIP_VERSION, ALLEGRO_RELEASE_NUMBER);

		assert(0, "The system Allegro version does not match the version of this binding!"); //why
		//  didn't they do this as an assert to begin with?
		}
/*	
	what was this supposed to be used for??
	
	cfg = al_load_config_file("test.ini"); // THIS ISN'T HERE, is it?
	if (cfg == null)
		{
		assert(0, "OMG WHERE CONFIG FILE.");
		}
	*/
	
static if (false) // MULTISAMPLING. Not sure if helpful.
	{
	with (ALLEGRO_DISPLAY_OPTIONS)
		{
		al_set_new_display_option(ALLEGRO_SAMPLE_BUFFERS, 1, ALLEGRO_REQUIRE);
		al_set_new_display_option(ALLEGRO_SAMPLES, 8, ALLEGRO_REQUIRE);
		}
	}

	al_display = al_create_display(g.SCREEN_W, g.SCREEN_H);
	queue	= al_create_event_queue();

	if (!al_install_keyboard())      assert(0, "al_install_keyboard failed!");
	if (!al_install_mouse())         assert(0, "al_install_mouse failed!");
	if (!al_init_image_addon())      assert(0, "al_init_image_addon failed!");
	if (!al_init_font_addon())       assert(0, "al_init_font_addon failed!");
	if (!al_init_ttf_addon())        assert(0, "al_init_ttf_addon failed!");
	if (!al_init_primitives_addon()) assert(0, "al_init_primitives_addon failed!");

	al_register_event_source(queue, al_get_display_event_source(al_display));
	al_register_event_source(queue, al_get_keyboard_event_source());
	al_register_event_source(queue, al_get_mouse_event_source());
	
	g.bmp  = al_load_bitmap("./data/mysha.pcx");
	g.font = al_load_font("./data/DejaVuSans.ttf", 18, 0);

	with(ALLEGRO_BLEND_MODE)
		{
		al_set_blender(ALLEGRO_BLEND_OPERATIONS.ALLEGRO_ADD, ALLEGRO_ALPHA, ALLEGRO_INVERSE_ALPHA);
		}
		
	//g.snow_color = al_map_rgba(255, 255, 255, 128); //can this be precalculated? we saw this in the DAllegro code i think. NOTE.
	g.snow_color = ALLEGRO_COLOR(0,0,0,1);
		
	// load animations/etc
	// --------------------------------------------------------
	load_resources();

	// SETUP world
	// --------------------------------------------------------
	world = new world_t;
	g.snow_bmp 	= al_load_bitmap("./data/snow.jpg");
	g.snowflake_bmp 	= al_load_bitmap("./data/snowflake.png");

	// Create objects for player's 1 and 2 as first two slots
	// --------------------------------------------------------
	skier_t player1 = new skier_t( 50, 50);
	skier_t player2 = new skier_t(200, 50);

	player1.set_animation(player_anim);	
	player2.set_animation(player_anim);
	
	world.objects ~= player1; //should be [0]
	world.objects ~= player2; //should be [1]
	
	// Create other objects.
	// --------------------------------------------------------
	world.populate_with_trees();
	world.populate_with_monsters();
	
	// SETUP player controls
	// --------------------------------------------------------
	with(keys_label)
		{
		player_controls[0].key[UP_KEY	] = ALLEGRO_KEY_UP;
		player_controls[0].key[DOWN_KEY	] = ALLEGRO_KEY_DOWN;
		player_controls[0].key[LEFT_KEY	] = ALLEGRO_KEY_LEFT;
		player_controls[0].key[RIGHT_KEY] = ALLEGRO_KEY_RIGHT;
		player_controls[0].key[FIRE_UP_KEY] = ALLEGRO_KEY_I;
		player_controls[0].key[FIRE_DOWN_KEY] = ALLEGRO_KEY_K;
		player_controls[0].key[FIRE_LEFT_KEY] = ALLEGRO_KEY_J;
		player_controls[0].key[FIRE_RIGHT_KEY] = ALLEGRO_KEY_L;
		player_controls[0].key[ACTION_KEY] = ALLEGRO_KEY_SPACE;
		player_controls[0].obj = world.objects[0];
		
		player_controls[1].key[UP_KEY	] = ALLEGRO_KEY_W;
		player_controls[1].key[DOWN_KEY	] = ALLEGRO_KEY_S;
		player_controls[1].key[LEFT_KEY	] = ALLEGRO_KEY_A;
		player_controls[1].key[RIGHT_KEY] = ALLEGRO_KEY_D;
		player_controls[1].key[FIRE_UP_KEY] = 0; //fixme
		player_controls[1].key[FIRE_DOWN_KEY] = 0;
		player_controls[1].key[FIRE_LEFT_KEY] = 0;
		player_controls[1].key[FIRE_RIGHT_KEY] = 0;
		player_controls[1].key[ACTION_KEY] = ALLEGRO_KEY_R;
		player_controls[1].obj = world.objects[1];
		}
	
	// SETUP viewports
	// --------------------------------------------------------
	viewports[0] = new viewport_t;
	viewports[0].x = 0;
	viewports[0].y = 0;
	viewports[0].width  = g.SCREEN_W/2;// - 1;
	viewports[0].height = g.SCREEN_H;
	viewports[0].offset_x = 0;
	viewports[0].offset_y = 0;

	viewports[1] = new viewport_t;
	viewports[1].x = g.SCREEN_W/2;
	viewports[1].y = 0;
	viewports[1].width  = g.SCREEN_W/2;//[ - 1;
	viewports[1].height = g.SCREEN_H;
	viewports[1].offset_x = 0;
	viewports[1].offset_y = 0;

	assert(viewports[0] !is null);
	
	// Finish object setup
	// --------------------------------------------------------	
	world.sort_objects_list(); //sort trees z-ordering above players, and higher trees behind lower trees. (drawn first.) 
	target.x = 590;
	target.y = 300;

	import std.random : uniform;

	for(int i = 0; i < g.NUM_SNOW_PARTICLES; i++)
		{
		viewports[0].snow.add(
			world.objects[0].x + uniform(-100,1000), //pos 
			world.objects[0].y + uniform(-100,1000), 
			uniform(0.0,5.0), // vel xy
			uniform(0.0,5.0)
				);
		viewports[1].snow.add(
			world.objects[1].x + uniform(-100,1000), //pos 
			world.objects[1].y + uniform(-100,1000), 
			uniform(0.0,5.0), // vel xy
			uniform(0.0,5.0)
				);
		}

	// FPS Handling
	// --------------------------------------------------------
	fps_timer = al_create_timer(1.0f);
	al_register_event_source(queue, al_get_timer_event_source(fps_timer));
	al_start_timer(fps_timer);
	
	return 0;
	}
	
struct display_t
	{
	void start_frame()	
		{
		stats.number_of_drawn_objects=0;
		stats.number_of_drawn_background_tiles=0;
		stats.number_of_drawn_particles=0;
		

		
		static if(DEBUG_NO_BACKGROUND)
			{
			reset_clipping(); //why would we need this? One possible is below! To clear to color the whole screen!
			al_clear_to_color(ALLEGRO_COLOR(.2,.2,.2,1)); //only needed if we aren't drawing a background
			}
		}
		
	void end_frame()
		{	
		al_flip_display();
		}

	void draw_frame()
		{
		start_frame();
		//------------------

		draw2();

		//------------------
		end_frame();
		}

	void reset_clipping()
		{
		al_set_clipping_rectangle(0, 0, g.SCREEN_W-1, g.SCREEN_H-1);
		}
		
	void draw2()
		{
		
	static if(true) //draw left viewport
		{
		al_set_clipping_rectangle(
			viewports[0].x, 
			viewports[0].y, 
			viewports[0].x + viewports[0].width ,  //-1
			viewports[0].y + viewports[0].height); //-1
		
		static if(DEBUG_NO_BACKGROUND)
			al_clear_to_color(ALLEGRO_COLOR(.7, .7, .7, 1));
		
		world.draw(viewports[0]);
		}

	static if(true) //draw right viewport
		{
		al_set_clipping_rectangle(
			viewports[1].x, 
			viewports[1].y, 
			viewports[1].x + viewports[1].width  - 1, 
			viewports[1].y + viewports[1].height - 1);

		static if(DEBUG_NO_BACKGROUND)
			al_clear_to_color(ALLEGRO_COLOR(.8,.7,.7, 1));

		world.draw(viewports[1]);
		}
		
		//Viewport separator
	static if(true)
		{
		al_draw_line(
			g.SCREEN_W/2 + 0.5, 
			0 + 0.5, 
			g.SCREEN_W/2 + 0.5, 
			g.SCREEN_H + 0.5,
			al_map_rgb(0,0,0), 
			10);
		}
		
		// Draw FPS and other text
		display.reset_clipping();
			al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "fps[%d]", stats.fps);
			al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "mouse [%d, %d][%d]", mouse_x, mouse_y, mouse_lmb);
			al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "target [%d, %d]", target.x, target.y);
			al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "number of drawn objects [%d], tiles [%d], particles [%d]", stats.number_of_drawn_objects, stats.number_of_drawn_background_tiles, stats.number_of_drawn_particles);
			
			al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "player1.xyz [%2.2f/%2.2f/%2.2f] v[%2.2f/%2.2f/%2.2f] d[%d]", world.objects[0].x, world.objects[0].y, world.objects[0].z, world.objects[0].x_vel, world.objects[0].y_vel, world.objects[0].z_vel, world.objects[0].direction);
			al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), 20, text_helper(false), ALLEGRO_ALIGN_LEFT, "player2.xy [%2.2f/%2.2f] v[%2.2f/%2.2f] d[%d]", world.objects[1].x, world.objects[1].y, world.objects[1].x_vel, world.objects[1].y_vel, world.objects[1].direction);
		text_helper(true);  //reset
		
		// DRAW MOUSE PIXEL HELPER/FINDER
		draw_target_dot(mouse_x, mouse_y);
		draw_target_dot(target.x, target.y);
		al_draw_textf(g.font, ALLEGRO_COLOR(0, 0, 0, 1), mouse_x, mouse_y - 30, ALLEGRO_ALIGN_CENTER, "mouse [%d, %d]", mouse_x, mouse_y);
		}
	}

//inline this? or template...
void draw_target_dot(xy_pair xy)
	{
	draw_target_dot(xy.x, xy.y);
	}

void draw_target_dot(float x, float y)
	{
	draw_target_dot(to!(int)(x), to!(int)(y));
	}

void draw_target_dot(int x, int y)
	{
	al_draw_pixel(x + 0.5, y + 0.5, al_map_rgb(0,1,0));

	immutable r = 2; //radius
	al_draw_rectangle(x - r + 0.5f, y - r + 0.5f, x + r + 0.5f, y + r + 0.5f, al_map_rgb(0,1,0), 1);
	}

/// For each call, this increments and returns a new Y coordinate for lower text.
int text_helper(bool do_reset)
	{
	static int number_of_entries = -1;
	
	number_of_entries++;
	immutable int text_height = 20;
	immutable int starting_height = 20;
	
	if(do_reset)number_of_entries = 0;
	
	return starting_height + text_height*number_of_entries;
	}

/// Update viewport positions based on player position and viewport size
void calculate_camera()
	{
	// Calculate camera
	viewports[0].offset_x = to!(int)(world.objects[0].x)-(viewports[0].width/2);
	viewports[0].offset_y = to!(int)(world.objects[0].y)-(viewports[0].height/2);

	viewports[1].offset_x = to!(int)(world.objects[1].x)-(viewports[1].width/2);
	viewports[1].offset_y = to!(int)(world.objects[1].y)-(viewports[1].height/2);
	}

void logic()
	{
	calculate_camera();
	world.logic();
	}

void execute()
	{
	bool exit = false;
	while(!exit)
		{
		ALLEGRO_EVENT event;
		while(al_get_next_event(queue, &event))
			{
			switch(event.type)
				{
				case ALLEGRO_EVENT_DISPLAY_CLOSE:
					{
					exit = true;
					break;
					}
				case ALLEGRO_EVENT_KEY_DOWN:
					{
					if(event.keyboard.keycode == ALLEGRO_KEY_I)
						{
						target.y--;
						}
					if(event.keyboard.keycode == ALLEGRO_KEY_K)
						{
						target.y++;
						}
					if(event.keyboard.keycode == ALLEGRO_KEY_J)
						{
						target.x--;
						}
					if(event.keyboard.keycode == ALLEGRO_KEY_L)
						{
						target.x++;
						}



					//THIS ISNT CACHED PER FRAME/DECOUPLED? OOOOOOOOOOOOOOOOOOOOOOF FIXME.
					with(keys_label)
					foreach(int i, keyset_t player_data; player_controls)
						{
						if(event.keyboard.keycode == player_data.key[UP_KEY])
							{
							writefln("Player %d - UP", i+1);
							player_data.obj.up();
							}
						if(event.keyboard.keycode == player_data.key[DOWN_KEY])
							{
							writefln("Player %d - DOWN", i+1);
							player_data.obj.down();
							}
						if(event.keyboard.keycode == player_data.key[LEFT_KEY])
							{
							writefln("Player %d - LEFT", i+1);
							player_data.obj.left();
							}
						if(event.keyboard.keycode == player_data.key[RIGHT_KEY])
							{
							writefln("Player %d - RIGHT", i+1);
							player_data.obj.right();
							}
						if(event.keyboard.keycode == player_data.key[ACTION_KEY])
							{
							writefln("Player %d - ACTION", i+1);
							player_data.obj.action();
							}
					
						if(event.keyboard.keycode == ALLEGRO_KEY_F)
							{
							import std.math : sin, cos, atan2;
							
							mouse_lmb = true;
							bullet_t b = new bullet_t;
//							object_t p = player_controls[0].obj;
							
							b.x = viewports[0].offset_x + viewports[0].width/2;
							b.y = viewports[0].offset_y + viewports[0].height/2;
							
							float x2 = mouse_x - viewports[0].width/2;
							float y2 = mouse_y - viewports[0].height/2;
							float a = atan2(y2, x2);
							
							float bv = g.bullet_velocity;
							
							b.x_vel = bv * cos(a);
							b.y_vel = bv * sin(a);
				
							b.a = a - 90 * 3.14159 / 180;  // move -90 deg because bullet png is offset
							world.bullet_h.add( b );
							}					
										
						}
							
					switch(event.keyboard.keycode)
						{					
						case ALLEGRO_KEY_ESCAPE:
							{
							exit = true;
							break;
							}
						default:
						}
						break;
					
					}
					
				case ALLEGRO_EVENT_MOUSE_AXES:
					{
					mouse_x = event.mouse.x;
					mouse_y = event.mouse.y;
					break;
					}


//kat work here
				case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
					{
					break;
					}
				
				case ALLEGRO_EVENT_MOUSE_BUTTON_UP:
					{
					mouse_lmb = false;
					break;
					}
				
				case ALLEGRO_EVENT_TIMER:
					{
					if(event.timer.source == fps_timer)
						{
						
						stats.fps = stats.frames_passed;
						stats.frames_passed = 0;
						}
					break;
					}
				
				default:
			}
		}

		logic();
		display.draw_frame();
		stats.frames_passed++;
//		Fiber.yield();  // THIS SEGFAULTS. I don't think this does what I thought.
//		pthread_yield(); //doesn't seem to change anything useful here. Are we already VSYNC limited to 60 FPS?
		}
	}

//best name? shutdown()? used. exit()? used. free? used. close()? used. finalize()? ???   --- Applicable name?
// Finalize? Destroy? Terminate? Kill? Cleanup? Uninitialize? Deinitialize?  
// >Dispose?
void terminate() //I think "shutdown" is a standard lib UNIX function. Easier for breakpointing by name.
	{
		
	}

//=============================================================================
int main(string [] args)
	{
	writeln("args length = ", args.length);
	foreach(size_t i, string arg; args)
		{
		writeln("[",i, "] ", arg);
		}
		
	if(args.length > 2)
		{
		g.SCREEN_W = to!int(args[1]);
		g.SCREEN_H = to!int(args[2]);
		writeln("New resolution is ", g.SCREEN_W, "x", g.SCREEN_H);
		}

	return al_run_allegro(
		{
		initialize();
		execute();
		terminate();
		return 0;
		} );
	}
