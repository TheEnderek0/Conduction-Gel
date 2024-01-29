function VectorDist(vec_a, vec_b)
{
    local vec = Vector(vec_a.x - vec_b.x, vec_a.y - vec_b.y, vec_a.z - vec_b.z); 
    return sqrt((vec.x * vec.x) + (vec.y * vec.y) + (vec.z * vec.z));
}

class TLink { //Every trigger has one link class, these classes can be "linked" together to create mesh systems

    id = null;
    entity = null;
    origin = null;
    name = null;
    linked_links = null;
    state = null;
    link_type = null;
    particle = null;
    __particle_origin = null; //TEMPORARY
    normal_vector = null;

    constructor(orig, vec) {
        name = false;
        origin = orig
        linked_links = [];
        state = false;
        link_type = 0; //Identify as normal TLink
        normal_vector = vec; //Used for particles
        id = DoUniqueString("tlink");
    }
    function AppendTrigger(ent) {
        if(ent == null) {printl("AppendTrigger called but trigger is null!"); return false;}
        entity = ent;

        this.entity.SetOrigin(this.origin);
        this.entity.SetForwardVector(this.normal_vector);
        this.name = ent.GetName();
        if(this.state) {
            EntFireByHandle(this.entity, "Enable", "", 0, null, null);
        }
    }
    function Find(object) { //Since this version of squirrel doesnt have built in find
        foreach(k, v in linked_links) {
            if(v.id == object.id) { //Add name checking here
                printl("Finding for " + object.id + " Found something!");
                printl("Found " + v.id+ " pairing with " + object.id);
                return k;
            }
        }
        printl("Finding for " + object.id + " yielded null!")
        return null;
    }

    function GetLinkName() {
        return name;
    }

    function GetLinkOrigin() {
        return origin;
    }

    function LinkEntity(link) {
        printl("=== Entity " + link.name + " ran link with me, " + this.name)
        if (link != null && Find(link) == null) { //Make sure it wasn't added before
            printl("Establishing link!")
            linked_links.append(link.weakref()); //Test if weakref won't cause any problems
            link.LinkEntity(this); //Link itself to that entity
            
            local st = VerifyState(); //Verify that you are active or not.
            if(st) {this.FireOn(this);}
            if(!st) {this.FireOff(this);}

            printl("Linked entities: " + this.name + " <---> " + link.name);
            return true;
        }
        return false;
    }

    function privUnlinkEntity(link) { //This function is run not here, but on every object that recieves a call from DestroyLink()
        local id = Find(link);
        if(id != null) {
            linked_links.remove(id);

            this.FireOff(this); //Do a fire off sequence, if that part is powered by a catcher it will return back online

            printl("Unlinked entities: " + this.name + " <-|  |-> " + link.name)
            return true;
        }
        return false;
    }

    function DestroyLink() { //Destroyes every link with this entity, kills the trigger and then awaits for garbage collection to be dematerialized
        foreach (k, v in linked_links)
        {
            v.privUnlinkEntity(this);
        }
        EntFireByHandle(particle, "Stop", "", 0.1, null, null);
        particle.SetOrigin(__particle_origin);
        linked_links.clear();
        try {entity.Destroy(); particle.Destroy();}
        catch (error) {printl("Error in DestroyLink: " + error)}
        return true;
    }

    function VerifyState() { //If there is any active neighbour you can stay activated but 
        foreach(k, v in linked_links) {
            if(v.state) {//If this equals true break the loop and return true
                return true;
            }
        }
        return false;//No neighbour is active
    }

    function FireOn(ent) {
        if(!state) {
            state = true;
            foreach(k, v in linked_links) {
                v.FireOn(this);
            }
            printl("Entity " + this.name + " changed status to " + state);
            try {
                if(particle == null) {throw "INFO: CG Lib, tlink called to change particle state but particle isn't set! "}
                EntFireByHandle(particle, "FireUser2", "", 0, null, null); //This has and is handled via I/O in the info_particle_system itself in main.vmf; for cancelpending to work properly
                EntFireByHandle(particle, "CancelPending", "", 0.05, null, null);
            } catch(error) {
                printl(error + this.name)
            }
            try {
                if(entity == null) {throw "FireOn called but no entity is set!"}
                EntFireByHandle(entity, "Enable", "", 0, null, null);
            }
            catch (error) {printl(error)}            
            //Enable this.entity
        }
        return false;
    }

    function FireOff(ent) {
        if(state) {
            state = false;
            foreach(k, v in linked_links) {
                v.FireOff(this);
            }
            printl("Entity " + this.name + " changed status to " + state);
            try {
                if (particle == null) {throw "INFO: CG Lib, tlink called to change particle state but particle isn't set! "}
                EntFireByHandle(particle, "FireUser3", "", 0, null, null);
            } catch (error) {
                printl(error + this.name)
            }
            try {
                if(entity == null) {throw "FireOff called but no entity is set!"}
                EntFireByHandle(entity, "Disable", "", 0, null, null);
            }
            catch (error) {printl(error)}
            //Disable this.entity
        }
        return false;
    }

    function AppendParticle(ent) { //Only in TLINK since emitters and catchers don't emit particles.
        this.particle = ent;
        if(this.state) {
            EntFireByHandle(particle, "Start", "", 0.1, null, null); //If the particle is late and the gel is already turned on, turn the particle on this way after appending
        }
        this.__particle_origin = ent.GetOrigin(); //Save the origin
        this.particle.SetOrigin(this.origin);
        local angles = this.particle.GetAngles();
        this.particle.SetForwardVector(this.normal_vector);
        angles += this.particle.GetAngles();
        this.particle.SetAngles(angles.x, angles.y, angles.z);

    }

}

class Emitter { //Every trigger has one link class, these classes can be "linked" together to create mesh systems

    id = null;
    entity = null;
    origin = null;
    name = null;
    linked_links = null;
    state = null;
    link_type = null;

    constructor(ent) {
        entity = ent;
        origin = ent.GetOrigin();
        name = "Emitter " + ent.GetName();
        linked_links = [];
        state = false;
        link_type = 1; //Identify as emitter
        id = DoUniqueString("cg_emitter");
    }

    function Find(object) { //Since this version of squirrel doesnt have built in find
        foreach(k, v in linked_links) {
            if(v.id == object.id) {
                return k;
            }
        }
        return null;
    }

    function GetLinkName() {
        return name;
    }

    function GetLinkOrigin() {
        return origin;
    }

    function LinkEntity(link) {
        if (link != null && Find(link) == null) { //Make sure it wasn't added before
            linked_links.append(link.weakref()); //Test if weakref won't cause any problems
            link.LinkEntity(this); //Link itself to that entity
            printl("Linked entities (EMITTER): " + this.name + " <---> " + link.name);
            return true;
        }
        return false;
    }

    function privUnlinkEntity(link) {
        local id = Find(link);
        if(id != null) {
            linked_links.remove(id);

            printl("Unlinked entities (EMITTER): " + this.name + " <-|  |-> " + link.name);
            return true;
        }
        return false;
    }

    function FireOn(ent) { //You can't turn an emitter online via gel
        try {
            if(ent.state != null) {
                return false;
            }
        }
        catch(error) {
        }
        
        state = true;
        foreach(k, v in linked_links) {
            v.FireOn(this);
        }
        printl("Entity " + this.name + " changed status to " + state);
        
        
        //Enable entities etc.
        
        return false;
    }

    function FireOff(prev) {
        try { //Is this an in game I/O event to de-activate the emitter or just a call from other objects?
            if(prev.state != null && this.state == true) { //If the state isn't null that means it is an object because I/O events don't have this functionality
                printl("Emitter bounce sequence!"); //This is an object, activate the chain again.
                EntFireByHandle(entity, "Test", "", 0.1, null, null) //We can't do this with FireOn since it will make a VERY big loop.
                
                return true;
            }
        }
        catch(error) {
            printl(error)
        }
        if(state) {
            state = false;
            foreach(k, v in linked_links) {
                v.FireOff(this);
            }
            printl("Entity " + this.name + " changed status to " + state);


            //Disable entities etc.
        }
        return false;
    }
}

class Catcher { //Every trigger has one link class, these classes can be "linked" together to create mesh systems

    id = null;
    entity = null;
    origin = null;
    name = null;
    linked_links = null;
    state = null;
    link_type = null;

    constructor(ent) { //This entity should be an logic_branch
        entity = ent;
        origin = ent.GetOrigin();
        name = "Catcher " + ent.GetName();
        linked_links = [];
        state = false;
        link_type = 2; //Identify as catcher
        id = DoUniqueString("cg_catcher");
    }

    function Find(object) { //Since this version of squirrel doesnt have built in find
        foreach(k, v in linked_links) {
            if(v.id == object.id) {
                return k;
            }
        }
        return null;
    }

    function GetLinkName() {
        return name;
    }

    function GetLinkOrigin() {
        return origin;
    }

    function LinkEntity(link) {
        if (link != null && Find(link) == null) { //Make sure it wasn't added before
            linked_links.append(link.weakref()); //Test if weakref won't cause any problems
            link.LinkEntity(this); //Link itself to that entity

            local st = VerifyState(); //Verify that you are active or not.
            if(st) {this.FireOn(this);}
            if(!st) {this.FireOff(this);}

            printl("Linked entities (CATCHER): " + this.name + " <---> " + link.name);
            return true;
        }
        return false;
    }

    function VerifyState() { //If there is any active neighbour you can stay activated but 
        foreach(k, v in linked_links) {
            if(v.state) {//If this equals true break the loop and return true
                return true;
            }
        }
        return false;//No neighbour is active
    }

    function privUnlinkEntity(link) {
        local id = Find(link);
        if(id != null) {
            linked_links.remove(id);

            this.FireOff(this); //Explained above

            printl("Unlinked entities (CATCHER): " + this.name + " <-|  |-> " + link.name);
            return true;
        }
        return false;
    }

    function FireOn(ent) {
        if(!state) {
            state = true;
            foreach(k, v in linked_links) { //This may be the end of the gel, but as well may be in the middle of a line and needs this functionality to pass the signal through further
                v.FireOn(this);
            }
            
            printl("Entity " + this.name + " changed status to " + state);
            EntFireByHandle(entity, "SetValueTest", "1", 0, null, null);
            EntFireByHandle(entity, "CancelPending", "", 0.05, null, null);
            //Enable
        }
        return false;
    }

    function FireOff(ent) {
        if(state) {
            state = false;
            foreach(k, v in linked_links) {
                v.FireOff(this);
            }

            printl("Entity " + this.name + " changed status to " + state);   
            EntFireByHandle(entity, "SetValueTest", "0", 0, null, null); //Logic branches should have from this output delayed
            //Disable
        }
        return false;
    }
}



//Vector math
function vector_length(v)
{
    // Return the length of a vector.
    return sqrt(pow(v.x, 2) + pow(v.y, 2) + pow(v.z, 2));
}


function vector_resize(v, f)
{
    // Return a vector colinear to v with length f.
    local len = vector_length(v);
    return v * (f / len);
}


function vector_dot(a, b)
{
    // Return the dot product of vectors a and b.
    return a.x*b.x + a.y*b.y + a.z*b.z
}


function make_rot_matrix(angles)
{
    // Return a 3x3 rotation matrix for the given pitch-yaw-roll angles.
    // (letters are swapped to get roll-yaw-pitch)
    //
    // format: / a b c \
    //         | d e f |
    //         \ g h k /

    local sin_x = sin(-angles.z / 180 * PI);
    local cos_x = cos(-angles.z / 180 * PI);
    local sin_y = sin(-angles.x / 180 * PI);
    local cos_y = cos(-angles.x / 180 * PI);
    local sin_z = sin(-angles.y / 180 * PI);
    local cos_z = cos(-angles.y / 180 * PI);

    return { a = cos_y * cos_z,   b = -sin_x * -sin_y * cos_z + cos_x * sin_z,   c = cos_x * -sin_y * cos_z + sin_x * sin_z,
             d = cos_y * -sin_z,  e = -sin_x * -sin_y * -sin_z + cos_x * cos_z,  f = cos_x * -sin_y * -sin_z + sin_x * cos_z,
             g = sin_y,           h = -sin_x * cos_y,                            k = cos_x * cos_y,
           }
}


function rotate(point, angles)
{
    // Rotate point about the origin by angles and return the result.

    local mx = make_rot_matrix(angles);
    return Vector(point.x * mx.a + point.y * mx.b + point.z * mx.c,
                  point.x * mx.d + point.y * mx.e + point.z * mx.f,
                  point.x * mx.g + point.y * mx.h + point.z * mx.k);
}


function unrotate(point, angles)
{
    // Rotate point about the origin by angles in the opposite direction
    // and return the result.
    //
    // This is very straightforward, as the inverse of the rotation
    // matrix is the original one with the rows and columns swapped.

    local mx = make_rot_matrix(angles);
    return Vector(point.x * mx.a + point.y * mx.d + point.z * mx.g,
                  point.x * mx.b + point.y * mx.e + point.z * mx.h,
                  point.x * mx.c + point.y * mx.f + point.z * mx.k);
}
