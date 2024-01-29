//This script is a lib of cg_main.nut

function ApplyCleanse(location) {
    //We have the entities, now we need to check where it landed
    //We can use the same trace array as the one in placing, since it's
    local indexes = [];
    foreach(k, v in active_links) { //Maybe we don't need to use another loop in a loop?
            if(VectorDist(v.GetLinkOrigin(), location) <= bomb_wall_dist && v.link_type == 0) { //If this is true that means the cleansing bomb hit this trigger and it needs to be removed
                v.DestroyLink(); //Destroys the link with other entities                                //Don't destroy catchers and emitters
                indexes.append(k); //Add this index to the indexes array
                printl("==Index appended: " + k)
        }
    }
    indexes.sort() //We need to sort the table since the indexes in active links will change dynamically throwing index out of range error
    for(local key = 0; key < indexes.len(); key++)
    {
        local value = indexes[key];
        value -= key //Explained above, remove 1 every time we remove something
        printl(value);
        active_links.remove(value); //Remove the link since it was cleansed
    }
}

function WipeTriggers() {
    foreach(k, v in active_links) {
        try {
            v.DestroyLink(); //Destroys the link with other entities
        }
        catch(error) {

        }
    }
    active_links.clear();
    trace_results = [null, null, null, null, null, null];
    return;
}