/*

This script places triggers where bombs hit.

*/

IncludeScript("lib");
IncludeScript("cleanse_triggers_lib");

SendToConsole("reflect_paint_color 75 152 152 255")

dirs <- [Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1)];
bomb_wall_dist <- 86; // *2
//DON'T MANUALLY PUT TRIGGERS WITH THE SAME CLASSNAME CLOSER THAN THIS DISTANCE!


::active_links <- [];
::script_handle <- self;
trace_results <- [null, null, null, null, null, null]; //Store results of the latest trace

link_distance <- 200; // Distance where links can link to each other
catch_emit_link_distance <- 150; //Used when we're linking to an emitter or a catcher, because they are smaller
break_distance <- 40;

MASK <- (CONTENTS_SOLID);
function Trace(dist, dir, origin)
{
    return TraceLineEx(origin, dir * dist + origin, MASK, GetPlayer(), COLLISION_GROUP_NONE); //We only want it to collide with paintable world
}

function ApplyTrigger(location) //Apply the triggers
{
    //We have the entities, now we need to check where it landed
    foreach(k, v in dirs)
    {
        local smallest_trace = null;
        local trace = Trace(bomb_wall_dist, v, location);
        if(trace.DidHit())
        {
            trace_results[k] = trace;

            if(smallest_trace > trace.GetFraction())
            {
                smallest_trace = trace.GetFraction();
            }
        }
    }
    local appendingTraces = [];
    foreach(k, v in trace_results)
    {
        local distance_bk = false;
        if(v != null) { if(v.DidHitWorld()) //Full 128x128 surface is coated (was 0.5) We now don't use grid placement since it complicated things way too much and was pretty useless
        { //Ifs above need to be nested because if v is null then it will error
            foreach(val_index, entity in active_links) {
                if(entity.link_type == 0) { //Check if this isn't a catcher or an emitter
                    local dist_b = VectorDist(entity.GetLinkOrigin(), location) //Return the distance between given entities
                    printl("---------DIST Between " + entity.name + " = " + dist_b);
                    if(dist_b < break_distance)
                    {
                        distance_bk = true; //Skip this trace and go to a next one (next comment below)
                    }
                }
            }
            if(distance_bk) {continue;} //Skip this trace and go to the next one
            appendingTraces.append(v);
        }
    }}
    foreach(k, v in appendingTraces) { //We need to do this here since distance checking was breaking it
        EntFireByHandle(EntityGroup[3], "ForceSpawn", "", 0, null, null); //Spawn the trigger
        EntFireByHandle(EntityGroup[4], "ForceSpawn", "", 0, null, null); //Spawn the particle
        Link(v.GetEndPos(), v.GetImpactNormal()); //Add entity to linking system
    }
    trace_results = [null, null, null, null, null, null]; //Clean the array
}


function Link(origin, vec) {
    local link = TLink(origin, vec); //Create a new TLink object
    local _old_link_distance = link_distance;
    //Check distance from every link and link to close ones. 
    foreach(k, v in active_links) {
        if(v.link_type != 0) {link_distance = catch_emit_link_distance;} //When linking to a catcher or an emitter, lower the distance
        printl("FOR " + v.name + "The distance between new is " + VectorDist(v.GetLinkOrigin(), link.GetLinkOrigin()));
        if(VectorDist(v.GetLinkOrigin(), link.GetLinkOrigin()) < link_distance) { //Check the distance between origins to determine if the gel links there
            printl("Ran link for " + v.name)
            v.LinkEntity(link); //Link objects together
        }
        link_distance = _old_link_distance;
    }

    active_links.append(link); //At the end add this link to the global link list, even if it has not been added anywhere
}

ball_properties <- ["allowfunnel", "1", "allowsilentdissolve", "0", "angles", 
"0 0 0", "body", "0", "bombtype", "0", "rendermode", "0", "model", "models/error.mdl", 
"painttype", "1", "playspawnsound", "1", "renderfx", "0", "renderamt", "255", "rendercolor", "255 255 255",
"skin", "0" , "solid", "0", "texframeindex", "0", "viewhideflags", "0"];


function ThrowBall(type) { //A developer function to fire gel blobs in game
    if(GetDeveloperLevel() < 1) {printl("ThrowBall called but developer mode is not set!"); return null};
    try {
        if(type) {
            EntFireByHandle(EntityGroup[0], "ForceSpawn", "", 0, null, null);
            EntFireByHandle(self, "RunScriptCode", "OnBallSpawn(true)", 0.02, null, null)
        }
        if(!type) {
            EntFireByHandle(EntityGroup[2], "ForceSpawn", "", 0, null, null);
            EntFireByHandle(self, "RunScriptCode", "OnBallSpawn(false)", 0.02, null, null)
        }
    }
    catch(error) {
        printl("Throwball error: " + error);
    }
    return null;
}

function OnBallSpawn(bool) {
    
    local entity = Entities.FindByClassnameWithin(null, "prop_paint_bomb", EntityGroup[0].GetOrigin(), 64);

    entity.SetOrigin(GetPlayer().EyePosition() + rotate(Vector(100, 0, 0), GetPlayer().EyeAngles())); //Set the origin once again so it starts from a proper position
    try {
        EntityGroup[1].SetOrigin(GetPlayer().EyePosition());
        EntFireByHandle(EntityGroup[1], "Explode", "", 0, null, null);
    }
    catch(error) {
        printl("No explosion set! " + error);
    }
    TrackEntity(entity, bool);
    return entity;
}


function TrackEntity(entity, bool) {
    entity.ValidateScriptScope();
    local scope = entity.GetScriptScope();
    if(bool) {scope.Explode <- BombExploded;} //Add this function to the entity's script scope
    if(!bool) {scope.Explode <- BombExploded_C;} //Special variant for cleansing gel
    entity.ConnectOutput("OnExploded", "Explode");
    return null;
}

function BombExploded() {
    local origin = activator.GetOrigin();
    //printl("BombExploded!");

    script_handle.ValidateScriptScope();
    local script_handle_scope = script_handle.GetScriptScope();
    script_handle_scope.ApplyTrigger(origin); //We need this since this function runs on the bomb itself not here
}

function BombExploded_C() { //Cleansing variant
    local origin = activator.GetOrigin();
    //printl("BombExploded!");

    script_handle.ValidateScriptScope();
    local script_handle_scope = script_handle.GetScriptScope();
    script_handle_scope.ApplyCleanse(origin);
}

function AppendCatcher(ent) {
    printl("Append catcher " + ent);
    local object = Catcher(ent); //Make a new catcher object
    active_links.append(object);
    return null;
}

function AppendEmitter(ent) {
    printl("Append emitter: " + ent);
    local object = Emitter(ent);
    active_links.append(object);

    ent.ValidateScriptScope();
    local scope = ent.GetScriptScope();
    scope.EmitterOn <- EmitterOn;
    scope.EmitterOff <- EmitterOff;
    scope.object <- object;

    ent.ConnectOutput("OnTrue", "EmitterOn");
    ent.ConnectOutput("OnFalse", "EmitterOff");
    return null;
}

function EmitterOn() { //These two functions are transfered to the logic_branch entity itself
    object.FireOn(self);
}

function EmitterOff() {
    object.FireOff(self);
}

function AppendParticle(ent) { //Called when particle spawns, append a particle to the latest TLINK
    ent.__KeyValueFromString("targetname", "cg_par_" + DoUniqueString(""));
    printl("Particle appended!" + ent)
    foreach(index, object in active_links) {
        if(object.link_type != 0) {continue}
        if(object.particle == null) {
            object.AppendParticle(ent);
            break;
        }
    }
}

function AppendTrigger(ent) {
    ent.__KeyValueFromString("targetname", "cg_tg_" + DoUniqueString(""));
    printl("Trigger appended! " + ent);
    foreach(index, object in active_links) {
        if(object.link_type != 0) {continue}
        if(!object.name) {
            object.AppendTrigger(ent);
            break;
        }
    }
}