void PlanetScattering_float(
	float3 start, // the start of the ray (the camera position)
    float3 dir, // the direction of the ray (the camera vector)
    float max_dist, // the maximum distance the ray can travel (because something is in the way, like an object)
    float3 light_dir, // the direction of the light
    float3 light_intensity, // how bright the light is, affects the brightness of the atmosphere
    float3 planet_position, // the position of the planet
    float planet_radius, // the radius of the planet
    float atmo_radius, // the radius of the atmosphere
    float3 beta_ray, // the amount rayleigh scattering scatters the colors (for earth: causes the blue atmosphere)
    float3 beta_mie, // the amount mie scattering scatters colors
    float3 beta_absorption, // how much air is absorbed
    float3 beta_ambient, // the amount of scattering that always occurs, cna help make the back side of the atmosphere a bit brighter
    float g, // the direction mie scatters the light in (like a cone). closer to -1 means more towards a single direction
    float height_ray, // how high do you have to go before there is no rayleigh scattering?
    float height_mie, // the same, but for mie
    float height_absorption, // the height at which the most absorption happens
    float absorption_falloff, // how fast the absorption falls off from the absorption height
    float steps_i, // the amount of steps along the 'primary' ray, more looks better but slower
    float steps_l, // the amount of steps along the light ray, more looks better but slower
    out float3 color,
    out float alpha
)
{
    // add an offset to the camera position, so that the atmosphere is in the correct position
    start -= planet_position;
    // calculate the start and end position of the ray, as a distance along the ray
    // we do this with a ray sphere intersect
    float a = 1;// dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (atmo_radius * atmo_radius);
    float d = (b * b) - 4.0 * a * c;
    
    // stop early if there is no intersect
    if (d < 0.0)
    {
        color = float3(0, 0, 0);
        alpha = 0;
        return;
    }
   
    
    // calculate the ray length
    float2 ray_length = float2(
        max((-b - sqrt(d)) / (2.0 * a), 0.0),
        min((-b + sqrt(d)) / (2.0 * a), max_dist)
    );
    
    // if the ray did not hit the atmosphere, return a back color
    if (ray_length.x > ray_length.y)
    {
        color = float3(0, 0, 0);
        alpha = 0;
        return;
    }
    

    // prevent the mie glow from appearing if there's an object in front of the camera
    bool allow_mie = max_dist > ray_length.y;
    // make sure the ray is no longer than allowed
    //ray_length.x = max(ray_length.x, 0.0);
    //ray_length.y = min(ray_length.y, max_dist);
    // get the step size of the ray
    float step_size_i = (ray_length.y - ray_length.x) / float(steps_i);
    
    // next, set how far we are along the ray, so we can calculate the position of the sample
    // if the camera is outside the atmosphere, the ray should start at the edge of the atmosphere
    // if it's inside, it should start at the position of the camera
    // the min statement makes sure of that
    float ray_pos_i = ray_length.x + step_size_i * 0.5;
    
    // these are the values we use to gather all the scattered light
    float3 total_ray = float3(0, 0, 0); // for rayleigh
    float3 total_mie = float3(0, 0, 0); // for mie
    
    // initialize the optical depth. This is used to calculate how much air was in the ray
    float3 opt_i = float3(0, 0, 0);
    
    // also init the scale height, avoids some float2's later on
    float2 scale_height = float2(height_ray, height_mie);
    
    // Calculate the Rayleigh and Mie phases.
    // This is the color that will be scattered for this ray
    // mu, mumu and gg are used quite a lot in the calculation, so to speed it up, precalculate them
    float mu = dot(dir, light_dir);
    float mumu = mu * mu;
    float gg = g * g;
    float phase_ray = 3.0 / (50.2654824574 /* (16 * pi) */) * (1.0 + mumu);
    float phase_mie = allow_mie ? 3.0 / (25.1327412287 /* (8 * pi) */) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg)) : 0.0;

    // now we need to sample the 'primary' ray. this ray gathers the light that gets scattered onto it
    for (int i = 0; i < steps_i; ++i)
    {
        
        // calculate where we are along this ray
        float3 pos_i = start + dir * ray_pos_i;
        
        // and how high we are above the surface
        float height_i = length(pos_i) - planet_radius;
        
        // now calculate the density of the particles (both for rayleigh and mie)
        float3 density = float3(exp(-height_i / scale_height), 0.0);
        
        // and the absorption density. this is for ozone, which scales together with the rayleigh, 
        // but absorbs the most at a specific height, so use the sech function for a nice curve falloff for this height
        // clamp it to avoid it going out of bounds. This prevents weird black spheres on the night side
        float denom = (height_absorption - height_i) / absorption_falloff;
        density.z = (1.0 / (denom * denom + 1.0)) * density.x;
        
        // multiply it by the step size here
        // we are going to use the density later on as well
        density *= step_size_i;
        
        // Add these densities to the optical depth, so that we know how many particles are on this ray.
        opt_i += density;
        
        // Calculate the step size of the light ray.
        // again with a ray sphere intersect
        // a, b, c and d are already defined
        a = dot(light_dir, light_dir);
        b = 2.0 * dot(light_dir, pos_i);
        c = dot(pos_i, pos_i) - (atmo_radius * atmo_radius);
        d = (b * b) - 4.0 * a * c;

        // no early stopping, this one should always be inside the atmosphere
        // calculate the ray length
        float step_size_l = (-b + sqrt(d)) / (2.0 * a * float(steps_l));

        // and the position along this ray
        // this time we are sure the ray is in the atmosphere, so set it to 0
        float ray_pos_l = step_size_l * 0.5;

        // and the optical depth of this ray
        float3 opt_l = float3(0, 0, 0);
            
        // now sample the light ray
        // this is similar to what we did before
        for (int l = 0; l < steps_l; ++l)
        {

            // calculate where we are along this ray
            float3 pos_l = pos_i + light_dir * ray_pos_l;

            // the heigth of the position
            float height_l = length(pos_l) - planet_radius;

            // calculate the particle density, and add it
            // this is a bit verbose
            // first, set the density for ray and mie
            float3 density_l = float3(exp(-height_l / scale_height), 0.0);
            
            // then, the absorption
            float denom = (height_absorption - height_l) / absorption_falloff;
            density_l.z = (1.0 / (denom * denom + 1.0)) * density_l.x;
            
            // multiply the density by the step size
            density_l *= step_size_l;
            
            // and add it to the total optical depth
            opt_l += density_l;
            
            // and increment where we are along the light ray.
            ray_pos_l += step_size_l;
            
        }
        
        // Now we need to calculate the attenuation
        // this is essentially how much light reaches the current sample point due to scattering
        float3 attn = exp(
        - beta_ray * (opt_i.x + opt_l.x)
        - beta_mie * (opt_i.y + opt_l.y)
        - beta_absorption * (opt_i.z + opt_l.z)
        );

        // accumulate the scattered light (how much will be scattered towards the camera)
        total_ray += density.x * attn;
        total_mie += density.y * attn;

        // and increment the position on this ray
        ray_pos_i += step_size_i;
    	
    }
    
    // calculate how much light can pass through the atmosphere
    float3 opacity = exp(-(
    beta_ray * opt_i.x + 
    beta_mie * opt_i.y +
    beta_absorption * opt_i.z
    ));
	// calculate and return the final color
    color = (
        	phase_ray * beta_ray * total_ray + // rayleigh color
       		phase_mie * beta_mie * total_mie + // mie
            opt_i.x * beta_ambient // and ambient
    ) * light_intensity;
    alpha = 1 - opacity;
    //alpha = 1;

}



void calculate_scattering_float(
	float3 start, // the start of the ray (the camera position)
    float3 dir, // the direction of the ray (the camera vector)
    float  max_dist, // the maximum distance the ray can travel (because something is in the way, like an object)
    float3 scene_color, // the color of the scene
    float3 light_dir, // the direction of the light
    float3 light_intensity, // how bright the light is, affects the brightness of the atmosphere
    float3 planet_position, // the position of the planet
    float  planet_radius, // the radius of the planet
    float  atmo_radius, // the radius of the atmosphere
    float3 beta_ray, // the amount rayleigh scattering scatters the colors (for earth: causes the blue atmosphere)
    float3 beta_mie, // the amount mie scattering scatters colors
    float3 beta_absorption, // how much air is absorbed
    float3 beta_ambient, // the amount of scattering that always occurs, cna help make the back side of the atmosphere a bit brighter
    float  g, // the direction mie scatters the light in (like a cone). closer to -1 means more towards a single direction
    float  height_ray, // how high do you have to go before there is no rayleigh scattering?
    float  height_mie, // the same, but for mie
    float  height_absorption, // the height at which the most absorption happens
    float  absorption_falloff, // how fast the absorption falls off from the absorption height
    float  steps_i, // the amount of steps along the 'primary' ray, more looks better but slower
    float  steps_l, // the amount of steps along the light ray, more looks better but slower
    out float3 color
)
{
    float alpha;
    PlanetScattering_float(
        start,
        dir,
        max_dist,
        light_dir,
        light_intensity,
        planet_position,
        planet_radius, 
        atmo_radius, 
        beta_ray,
        beta_mie, 
        beta_absorption, 
        beta_ambient, 
        g, 
        height_ray,
        height_mie,
        height_absorption,
        absorption_falloff,
        steps_i, 
        steps_l, 
        color,
        alpha
    );
    
    color += (1 - alpha) * scene_color;

}

void SphereIntersect_float(float3 position, float radius, float3 start, float3 dir,
    out float near, out float far)
{
    start -= position;
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
    float d = (b * b) - 4.0 * a * c;
    if (d < 0.0)
    {
        near = 0;
        far = 0;
        return;
    }
    near = max((-b - sqrt(d)) / (2.0 * a), 0.0);
    far  = (-b + sqrt(d)) / (2.0 * a);
    //if (ray_length.x > ray_length.y)
    //{
    //    color = float3(0, 0, 0);
    //    alpha = 0;
    //    return;
    //}
}

void ray_sphere_intersect_float(
    float3 start, // starting position of the ray
    float3 dir, // the direction of the ray
    float radius, // and the sphere radius
    out float d0,
    out float d1
)
{
    // ray-sphere intersection that assumes
    // the sphere is centered at the origin.
    // No intersection when result.x > result.y
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
    float d = (b * b) - 4.0 * a * c;
    d0 = (-b - sqrt(d)) / (2.0 * a);
    d1 = (-b + sqrt(d)) / (2.0 * a);
    if (d < 0.0 || d1 < d0)
    {
        // d0 = 1e5;
        // d1 = -1e5;
        d0 = 0;
        d1 = 0;
    }
}

void Test_float(out float test)
{
    test = 1;
}

