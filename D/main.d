// SkiiFree'd - KATKO 2017
//=============================================================================

import std.stdio;
import std.conv;
import std.string;
import std.format; //String.Format like C#?! Nope. Damn, like printf.

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


// CONSTANTS
//=============================================================================
immutable float JUMP_VELOCITY = 2.2F; //NYI

//world dimensions
immutable float maximum_x = 1000F; 	//NYI
immutable float maximum_y = 20000F; //NYI
immutable float maximum_z = 100F; 	//NYI

//GLOBALS
//=============================================================================
ALLEGRO_CONFIG* 		cfg;
ALLEGRO_DISPLAY* 		display;
ALLEGRO_EVENT_QUEUE* 	queue;

ALLEGRO_COLOR 			color1;
ALLEGRO_COLOR 			color2;
ALLEGRO_BITMAP* 		bmp;
ALLEGRO_FONT* 			font;

animation_t player_anim;
animation_t monster_anim;
animation_t tree_anim;
animation_t jump_anim;

keyset_t [2] player_controls;
object_t [] world_objects;
world_t world;

//=============================================================================

class animation_t
	{
	ALLEGRO_BITMAP *[] frames;
	string [] names;
	
	void load_extra_frame(string path)
		{
		ALLEGRO_BITMAP *extra_frame = al_load_bitmap( toStringz(path));
		frames ~= extra_frame;
		//names = to!string(); 
		names ~= "OOPS."; //filler, what happens if not unique? Return first result?
		}
		
	void load_extra_frame(string path, string name)
		{
		ALLEGRO_BITMAP *extra_frame = al_load_bitmap( toStringz(path));
		frames ~= extra_frame;
		names ~= name;
		}
		
	ALLEGRO_BITMAP* get_frame_by_number(int i)
		{
		ALLEGRO_BITMAP* x;
		return x;
		}
	ALLEGRO_BITMAP* get_frame_by_name(string name)
		{
		ALLEGRO_BITMAP* x;
		return x;
		}
	
	void draw(int frame, float x, float y)
		{
		al_draw_bitmap(frames[frame], x, y, 0);
		}
		
	void empty(){}
	}
	
void resources()	
	{
	player_anim	.load_extra_frame("./data/mysha.pcx");
	monster_anim.load_extra_frame("./data/mysha.pcx");
	tree_anim	.load_extra_frame("./data/mysha.pcx");
	jump_anim	.load_extra_frame("./data/mysha.pcx");
	}

//DEFINITELY want this to be a class / reference type!
class object_t //could we use a drawable_object whereas object_t has re-usable functionality for a camera_t?
	{
	public:
	float 		x, y, z; //objects are centered at X/Y (not top-left) so we can easily follow other objects.
	float		x_vel, y_vel, z_vel; //note Z is used for jumps.
	float		width, height;

	bool trips_you;
	bool slows_you_down;
	bool is_following_another_object; 
	object_t object_to_follow; 

	this()
		{
		trips_you = false;
		slows_you_down = false;
		is_following_another_object = false;
		}
		
	void follow_object(object_t obj)
		{
		is_following_another_object = true;
		object_to_follow = obj;
		}
	
	bool is_colliding_with(object_t obj)
		{
		// I freakin' love D.
		alias x2 = obj.x;
		alias y2 = obj.y;
		alias width2 = obj.width;
		alias height2 = obj.height;
		
		/* from https://wiki.allegro.cc/index.php?title=Bounding_Box   GO ALLEGRO GO
		*/
			
		if(	x  > x2 + width2  - 1 	|| 
			y  > y2 + height2 - 1 	||
			x2 > x  + width   - 1	||
			y2 > y  + height  - 1)
			{
			return false;
			}
		return true;
		}
	
	// INPUTS (do we support mouse input?)
	// ------------------------------------------
	void up(){}
	void down(){}
	void left(){}
	void right(){}
	void action(){} // ala space. for monster this would be EAT MWAHAHA. (or is that automatic?) LET HIM EAT OTHER PEOPLE AND STUFF TOO.
	void click_at(float relative_x, float relatie_y){} //maybe? relative to object coordinate.
	
	// EVENTS
	// ------------------------------------------
	void on_tick()
		{
		if(is_following_another_object)
			{
			x = object_to_follow.x;
			y = object_to_follow.y;
			}
		}

	void on_collision(object_t other_obj)
		{
		}	
	}
	
class camera_t : object_t 
	{
	// simply uses the follow object routines in object_t!
	}

class drawable_object_t : object_t
	{
	animation_t animation;

	void draw(int frame)
		{
		animation.draw(frame, x, y);
		}
	}
	
class tree_t : drawable_object_t
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
		alias o = other_obj; //this is kind of cool, we can CLEARLY label the variable, and then use a tiny/ABBREVIATION version.
		//or alias player =
		//or alias p =	
		o.z_vel += JUMP_VELOCITY;
		}
	}

class monster_t : drawable_object_t
	{
	override void on_tick()
		{
		//run torward assholes
		// need a find_player method. (what about multiple players?)
		// Do we also need an A* algorithm (or something more basic) for navigating around objects when stuck?
		// How do we get the monster to zig-zag like in the game?
		}
		
	override void on_collision(object_t other_obj) 
		{
		if(auto p = cast(player_t) other_obj)
			{
			// I'M GONNA EAT YOU, BUB.
			}		
		}
	}

class skier_t : drawable_object_t
	{
	override void on_tick()
		{
		x += x_vel;
		y += y_vel;
		z += z_vel;
		
		if(x < 0)
			{
			x_vel = 0;
			x = 0;
			}

		if(y < 0)
			{
			y_vel = 0;
			y = 0;
			}

		if(z < 0)
			{
			z_vel = 0;
			z = 0;
			}
		}
	}
	
class player_t : skier_t
	{

	}

class world_t
	{
	object_t [] objects;
	
	void test()
		{
		player_t x;
		objects ~= x; //polymorphism rules. 
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
		ALLEGRO_KEY [5] key;
		// If we support MOUSE clicks, we could simply attach a MOUSE in here 
		// and have it forward to the object's click_on() method.
		// But again, that kills the idea of multiplayer.
		}
		
enum
	{
	UP_KEY = 0,
	DOWN_KEY = 1,
	LEFT_KEY = 2,
	RIGHT_KEY = 3,
	ACTION_KEY = 4
	}

bool initialize()
	{
	if (!al_init())
		{
		auto ver = al_get_allegro_version();
		auto major = ver >> 24;
		auto minor = (ver >> 16) & 255;
		auto revision = (ver >> 8) & 255;
		auto release = ver & 255;

		writefln("The system Allegro version (%s.%s.%s.%s) does not match the version of this binding (%s.%s.%s.%s)",
			major, minor, revision, release,
			ALLEGRO_VERSION, ALLEGRO_SUB_VERSION, ALLEGRO_WIP_VERSION, ALLEGRO_RELEASE_NUMBER);

		assert(0, "The system Allegro version does not match the version of this binding!"); //why didn't they do this as an assert to begin with?
		}
		
	cfg = al_load_config_file("test.ini");
	display = al_create_display(500, 500);
	queue = al_create_event_queue();

	if (!al_install_keyboard())      assert(0, "al_install_keyboard failed!");
	if (!al_install_mouse())         assert(0, "al_install_mouse failed!");
	if (!al_init_image_addon())      assert(0, "al_init_image_addon failed!");
	if (!al_init_font_addon())       assert(0, "al_init_font_addon failed!");
	if (!al_init_ttf_addon())        assert(0, "al_init_ttf_addon failed!");
	if (!al_init_primitives_addon()) assert(0, "al_init_primitives_addon failed!");

	al_register_event_source(queue, al_get_display_event_source(display));
	al_register_event_source(queue, al_get_keyboard_event_source());
	al_register_event_source(queue, al_get_mouse_event_source());
	
	bmp = al_load_bitmap("./data/mysha.pcx");
	font = al_load_font("./data/DejaVuSans.ttf", 18, 0);

	with(ALLEGRO_BLEND_MODE)
		{
		al_set_blender(ALLEGRO_BLEND_OPERATIONS.ALLEGRO_ADD, ALLEGRO_ALPHA, ALLEGRO_INVERSE_ALPHA);
		}

	color1 = al_color_hsl(0, 0, 0);
	color2 = al_map_rgba_f(0.5, 0.25, 0.125, 1);
	writefln("%s, %s, %s, %s", color1.r, color1.g, color2.b, color2.a);
	
	// Create objects for player's 1 and 2
	// --------------------------------------------------------
	player_t player1;
	player_t player2;
	
	world_objects ~= player1; //should be [0]
	world_objects ~= player2; //should be [1]

	// SETUP player controls
	// --------------------------------------------------------
	player_controls[0].key[0] = 0;
	player_controls[0].key[DOWN_KEY	] = ALLEGRO_KEY_DOWN;
	player_controls[0].key[LEFT_KEY	] = ALLEGRO_KEY_LEFT;
	player_controls[0].key[RIGHT_KEY] = ALLEGRO_KEY_RIGHT;
	player_controls[0].key[ACTION_KEY] = ALLEGRO_KEY_SPACE;
	player_controls[0].obj = world_objects[0];
	
	player_controls[1].key[UP_KEY	] = ALLEGRO_KEY_W;
	player_controls[1].key[DOWN_KEY	] = ALLEGRO_KEY_S;
	player_controls[1].key[LEFT_KEY	] = ALLEGRO_KEY_A;
	player_controls[1].key[RIGHT_KEY] = ALLEGRO_KEY_D;
	player_controls[1].key[ACTION_KEY] = ALLEGRO_KEY_R;
	player_controls[1].obj = world_objects[1];

	return 0;
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
				case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
				{
					exit = true;
					break;
				}
				default:
			}
		}

		al_clear_to_color(ALLEGRO_COLOR(0.5, 0.25, 0.125, 1));
		al_draw_bitmap(bmp, 50, 50, 0);
		al_draw_triangle(20, 20, 300, 30, 200, 200, ALLEGRO_COLOR(1, 1, 1, 1), 4);
		al_draw_text(font, ALLEGRO_COLOR(1, 1, 1, 1), 70, 40, ALLEGRO_ALIGN_CENTRE, "Hello!");
		al_flip_display();
		}
	}

//best name? shutdown()? used. exit()? used. free? used. close()? used. finalize()? ???   --- Applicable name?
// Finalize? Destroy? Terminate? Kill? Cleanup? Uninitialize? Deinitialize?  
// >Dispose?
void terminate() //I think "shutdown" is a standard lib UNIX function. Easier for breakpointing by name.
	{
		
	}


//=============================================================================
int main(char[][] args)
	{
	
	return al_run_allegro(
		{
		initialize();
		execute();
		terminate();
		return 0;
		} );


	}
