//-----------------------------------------------------------------------------------
// SCREEN SPACE REFLECTIONS
// 
// Made by error.mdl, Toocanz, and Xiexe.
//
//-----------------------------------------------------------------------------------

/*
Include these properties in your shader to control the SSR's behavior

		[Header(Screen Space Reflection Settings)] 
		_SSRTex ("SSR mask", 2D) = "white" {}
		_NoiseTex("Noise Texture", 2D) = "black" {}
		[Toggle] _dith("Low Res", int) = 0
		_alpha("Reflection Strength", Range(0.0, 1.0)) = 1
		_rtint("Reflection Tint Strength", Range(0.0, 1.0)) = 0
		_blur("Blur (does ^2 texture samples!)", Float) = 8
		_MaxSteps ("Max Steps", Int) = 100
		_step("Ray step size", Float) = 0.09 
		_lrad("Large ray intersection radius", Float) = 0.2
		_srad("Small ray intersection radius", Float) = 0.02
		_edgeFade("Edge Fade", Range(0,1)) = 0.1
*/ 

sampler2D_float _CameraDepthTexture;



/** @brief Check to see if the camera rendering the pixel is a mirror camera.
 *
 *	Mirror cameras can't properly do SSR cause they try to use the main
 *  camera's depth texture, and rendering the SSR effect twice more (currently
 *  one camera for each eye in the mirror) is extremely expensive. Thus we want
 *  to stop the raymarch immediately if the shader is being rendered by a
 *  mirror camera
 *
 * @return True if the camera is a mirror, false otherwise
 */
bool IsInMirror()
{
		return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}




/** @brief Dumb method of blurring the grabpass.
 *
 *  Normal cubemap style reflections simulate rough reflections by using lower
 *  mipmap levels of the cubemap. Unfortunately, we can't get lower mip-maps
 *  of a grab-pass (at least on the old unity render pipeline, in the HD
 *  render pipeline the one pre-defined grabpass you get has mip levels).
 *  Thus, in order to blur the grabpass texture I'm just sampling a bunch of
 *  pixels in a square and averaging the color.
 *
 * @param uvs Uv coordinate of the pixel on grabpass.
 * @param dim Width/height of the square of pixels to sample around uvs
 */
float3 getBlurredGP(const sampler2D GrabTextureSSR, const float2 TexelSize, const float2 uvs, const float dim)
{
	float2 pixSize = 2/TexelSize;
	float center = floor(dim*0.5);
	float3 refTotal = float3(0,0,0);
	for (int i = 0; i < floor(dim); i++)
	{
		for (int j = 0; j < floor(dim); j++)
		{
			float4 refl = tex2Dlod(GrabTextureSSR, float4(uvs.x + pixSize.x*(i-center), uvs.y + pixSize.y*(j-center),0,0));
			refTotal += refl.rgb;
		}
	}
	return refTotal/(floor(dim)*floor(dim));
}



/** @brief March a ray from a given position in a given direction
 *         until it intersects the depth buffer.
 *
 *  Given a starting location and direction march a ray in fixed steps. Each
 *  step convert the ray's position to screenspace coordinates and depth, and
 *  compare to the the depth texture's value at that locaion. If the ray is
 *  within largeRadius of the depth buffer, reduce the fixed step size to 1/10
 *  of the original value. If the depth in the depth texture is also smaller
 *  than the rays current depth, reverse the direction. Repeat until the ray
 *  is within smallRadius of the depth texture or the maximum number of
 *  iterations is exceeded. Additionally, the loop will be cut short if the
 *  ray passes out of the camera's view.
 *  
 *  @param reflectedRay Starting position of the ray, in world space
 *  @param rayDir Direction the ray is going, in world space
 *  @param largeRadius Distance above/below the depth texture the ray must be
 *         within before it will slow down and possibly reverse direction.
 *         Expressed in world-space units
 *  @param smallRadius Distance above/below the depth texture the ray must be
 *         before it can be considered to have successfully intersected the
 *         depth texture. World-space units.
 *  @param stepSize Initial (large) size of the steps the ray moves each
 *         iteration before it gets within largeRadius of the depth texture.
 *         In world space coordinates/scale
 *  @param noise Random noise added to offset the ray's starting position.
 *         This dramatically helps to hide repeating artifacts from the ray-
 *         marching process.
 *  @param maxIterations The maximum number of times we can step the ray
 *         before we give up.
 *  @return The final xyz position of the ray, with the number of iterations
 *          it took stored in the w component. If the function ran out of
 *          iterations or the ray went off screen, the xyz will be (0,0,0).
 */
float4 reflect_ray(float4 reflectedRay, float4 rayDir, float largeRadius, float smallRadius, float stepSize, float noise, const int maxIterations)
{
	/* 
     *  If we are in VR, we have effectively two screens side by side in a single texture. We want to stop the ray if it goes off screen. The problem is, we can't simply look at
	 *  the screen-space uv coordinates as a ray could pass from one eye to the other staying within the 0 to 1 uv range. Thus, we need to make sure the ray doesn't go off the
	 *  half of the screen that the eye rendering it occupies. Thus, the horizontal range is 0 to 0.5 for the left eye and 0.5 to 1 for the right.
	 */
	 
	#if UNITY_SINGLE_PASS_STEREO
		half x_min = 0.5*unity_StereoEyeIndex;
		half x_max = 0.5 + 0.5*unity_StereoEyeIndex;
	#else
		half x_min = 0.0;
		half x_max = 1.0;
	#endif
	
	//Matrix that goes directly from world space to view space.
	static const float4x4 worldToDepth = mul(UNITY_MATRIX_MV, unity_WorldToObject);
	
	reflectedRay = mul(worldToDepth, float4(reflectedRay.xyz, 1));
	rayDir = mul(worldToDepth, float4(rayDir.xyz, 0));
	
	int totalIterations = 0;//For tracking how far this ray has gone for fading out later
	
	
	// Controls whether the ray is progressing forward or back along the ray
	// path. Set to 1, the ray goes forward. Set to -1, the ray goes back.
	int direction = 1;
	
	// Final position of the ray where it gets within the small radius of the depth buffer
	float4 finalPos = float4(0,0,0,1);
	
	for (int i = 0; i < maxIterations; i++)
	{
		totalIterations = i;

		float4 spos = ComputeGrabScreenPos(mul(UNITY_MATRIX_P, reflectedRay));

		float2 uvDepth = spos.xy / spos.w;

		//If the ray is outside of the eye's portion of the screen, we can stop there's no relevant information here
		if (uvDepth.x > x_max || uvDepth.x < x_min || uvDepth.y > 1 || uvDepth.y < 0)
		{
			break;
		}


		float rawDepth = DecodeFloatRG(tex2Dlod(_CameraDepthTexture,float4(uvDepth,0,0)));
		float linearDepth = Linear01Depth(rawDepth);
		

		//float sampleDepth = -mul(worldToDepth, float4(reflectedRay.xyz, 1)).z;
		float sampleDepth = -reflectedRay.z;
		float realDepth = linearDepth * _ProjectionParams.z;

		float depthDifference = abs(sampleDepth - realDepth);

		// If the ray is within the large radius, check if it is within the small radius.
		// If it is, stop raymarching and set the final position. If it is not, decrease
		// the step size and possibly reverse the ray direction if it went past the small
		// radius
		if (depthDifference < largeRadius)
		{ 
			if (direction == 1)
			{
					 
				if(sampleDepth > realDepth - smallRadius)
				{
					if(sampleDepth < realDepth + smallRadius)
						{
							finalPos = reflectedRay;
							break;
						}
				direction = -1;
				stepSize = stepSize*0.1;
				}
			}
			else
			{
				if(sampleDepth < realDepth + smallRadius)
				{
					/*
					if(sampleDepth > realDepth - smallRadius)
					{
						finalPos = reflectedRay;
						break;
					}
					*/
					direction = 1;
					
					stepSize = stepSize*0.1;
				}
			}
			
			
		}
		
		reflectedRay = reflectedRay + direction*stepSize*rayDir;
		
		// increase the speed of the ray and search radius as the ray gets farther away
		stepSize += stepSize*(0.025 + 0.005*noise);
		largeRadius += largeRadius*(0.025 + 0.005*noise);
		smallRadius += smallRadius*(0.025 + 0.005*noise);
	}
	// We're going to throw the number of iterations into the w component of the final ray position cause we'll need that later, and we know for a fact
	// that w is always going to be 1 (its a position, not a direction) so we don't really need it anyways other than for coordinate space transformations.
	return float4(finalPos.xyz, totalIterations);
}


/** @brief Gets the reflected color for a pixel
 *
 *	@param wPos World position of the pixel
 *  @param wNormal World-space normal direction
 *  @param faceNormal Raw mesh normal direction
 *  @param largeRadius Large intersection radius for the ray (see reflect_ray())
 *  @param smallRadius Small intersection radius for the ray (see reflect_ray())
 *  @param stepSize initial step size for the ray (see reflect_ray())
 *  @param blur Square root of the max number of texture samples that can be taken to blur the grabpass
 *  @param maxSteps Max number of steps the ray can go
 *  @param isLowRes Only do SSR on 1 out of every 2x2 pixel block if 1, otherwise do on every pixel if 0
 *  @param smoothness Smoothness, determines how blurred the grabpass is, how scattered the rays are, and how strong the reflection is
 *  @param edgeFade How far off the edges of the screen the reflection gets faded out
 *  @param scrnParams width, height of screen in pixels (It is wise to use the zw components of the texel size of the grabpass for this,
 *		   unity's screen params give the wrong width for single pass stereo cameras)
 *  @param GrabTextureSSR Grabpass sampler
 *  @param NoiseTex Noise texture sampler
 *  @param NoiseTex_dim width/height of the noise texture
 *  @param albedo Albedo color of the pixel
 *  @param metallic How strongly the reflection color is influenced by the albedo color
 *  @param rtint Override for how metallic the surface is, not necessary, I should remove this.
 *  @param mask Mask for how strong the SSR is. Useful for making the SSR only affect certain parts of a material without making them less smooth
 *  @param reflStr Multiplier for how intense the SSR should be
 */
 
 
float4 getSSRColor(
					float4 wPos,
					half3 wNormal,
					half3 faceNormal,
					float largeRadius,
					float smallRadius,
					float stepSize,
					float blur,
					int maxSteps,
					int isLowRes,
					float smoothness,
					float edgeFade,
					float2 scrnParams,
					sampler2D GrabTextureSSR,
					sampler2D NoiseTex,
					float2 NoiseTex_dim,
					float4 albedo,
					float metallic,
					float rtint,
					float mask,
					float reflStr
					)
{
	// Trace a vector from the camera to the world-space location of the pixel being rendered.
	float3 viewDir = normalize(wPos.xyz - _WorldSpaceCameraPos);
	
	//Calculate the direction of the reflected ray off the surface
	float4 rayDir = float4(reflect(viewDir, wNormal).xyz,0);
	
	/*
	 * Calculate the cos of the angle between the view direction of the pixel and the reflected ray
	 * We'll use this later to skip raymarching if the reflected ray is coming back towards the camera
	 */
	float RdotV = dot(rayDir.xyz, viewDir);
	
	/*
	 * Calculate the cos of the angle between the surface (ignoring normal maps) and the reflected ray.
	 * We'll use this later to make sure the normal from the normal map didn't make us reflect a ray
	 * whose direction goes underneath the face it's reflecting off of.
	 */
	float FdotR = dot(faceNormal, rayDir.xyz);

	/*
	 * Calculate the screenspace position of the pixel for
	 * dithering. Note we can't use the same float4 for the
	 * final uv coordinates as the compiler will do some
	 * bad optimization that makes dithering loose its
	 * performance benefit entirely. Not sure why though.
	 */

	float4 screenUVs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos)));
	screenUVs.xy = screenUVs.xy / screenUVs.w;
	
	
	
	
	/*
	 * Read noise from a blue noise texture. We'll use this to randomly rotate/offset the ray and
	 * slightly change its speed to hide repeating artifacts like banding due to the step size
	 * and to fake blurring for lower smoothness surfaces by scattering the rays.
	 */
	float4 noiseUvs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos)));
	noiseUvs.xy = (noiseUvs.xy * scrnParams) / (NoiseTex_dim * noiseUvs.w);	
	//noiseUvs.xy = noiseUvs.xy/((scrnParams*NoiseTex_dim) * noiseUvs.w);	
	float4 noiseRGBA = tex2Dlod(NoiseTex, float4(noiseUvs.xy,0,0));
	float noise = noiseRGBA.r;
	
	
	/*
	 * Initially move the reflected ray forward a step. We need to move the ray forward enough that
	 * the ray will not hit the reflected surface's depth before it has a chance to move.
	 * This is an overestimate of how far the ray needs to move. Could be better, but I'm too lazy to
	 * do the math to get the smallest amount necessary.
	 */
	
	float4 reflectedRay = wPos + (largeRadius*stepSize/FdotR + noise*stepSize)*rayDir;
	
	// scatter rays based on roughness. WARNING. CAN BE EXTREMELY EXPENSIVE. RANDOM AND SPREAD OUT TEXTURE SAMPLES ARE VERY INEFFCIENT
	// YOU MAY WANT TO REMOVE THIS.
	float scatterMult = 0.2;
	float4 scatter = float4(0.5 - noiseRGBA.rgb,0);
	rayDir = normalize(rayDir + scatterMult*scatter*(1-smoothness)*sqrt(FdotR));
	
	/*
	 * If isLowRes is 1, only raymarch the pixels that have even x and y coordinates
	 * ie only do 1 out of every 2x2 block of pixels. This should save on performance.
	 */
	int dither = floor(fmod(scrnParams.x*screenUVs.x,2)) + floor(fmod(scrnParams.y*screenUVs.y,2));
	dither *= isLowRes;
	UNITY_BRANCH if (dither != 0) {
		return float4(0,0,0,0);
	}
	/*
	 * Don't raymarch if the ray is coming back towards the camera (RdotV < 0) or
	 * the ray is going into the surface (FdotR < 0).
	 * EDIT: don't do the RdotV check, rays coming back towards the camera can be useful
	 * in some cases
	 */
	else if (FdotR < 0)	//else if (FdotR < 0 || RdotV < 0)
	{
		return float4(0,0,0,0);
	}
	/*
	 * Begin the actual raymarching process
	 */
	else
	{
		

		
		/*
		 * Controls whether the ray is progressing forward or back along the ray
		 * path. Set to 1, the ray goes forward. Set to -1, the ray goes back.
		 */
		int back = 1;
		
		
		
		
		/*
		 * Do the raymarching against the depth texture. See SSR.cginc for the implementation of
		 * reflect_ray(). This returns a world-space position where the ray hit the depth texture,
		 * along with the number of iterations it took stored as the w component.
		 */
		
		float4 finalPos = reflect_ray(reflectedRay, rayDir, largeRadius, smallRadius, stepSize, noise, maxSteps);
		
		
		// get the total number of iterations out of finalPos's w component and replace with 1.
		float totalSteps = finalPos.w;
		finalPos.w = 1;
		
		/*
		 * A position of 0, 0, 0 signifies that the ray went off screen or ran
		 * out of iterations before actually hitting anything.
		 */
		if (finalPos.x == 0 && finalPos.y == 0 && finalPos.z == 0) 
		{
			return float4(0,0,0,0);
		}
		
		/*
		 * Get the screen space coordinates of the ray's final position
		 */
		float4 uvs;			
		//uvs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, finalPos)));
		uvs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_P, finalPos)));
		uvs.xy = uvs.xy / uvs.w;
					
		
	
	
	
		/*
		 * Fade towards the edges of the screen. If we're in VR, we can't really
		 * fade horizontally all that well as that results in stereo mismatch (the
		 * reflection will begin to fade in different locations in each eye). Thus
		 * just don't fade on X in VR. This isn't really a problem as we have tons
		 * of screen real estate that is not within the FOV of the headset and thus
		 * we can actually reflect some stuff that is technically off-screen.
		 */
		
		#if UNITY_SINGLE_PASS_STEREO
		float xfade = 1;
		#else
		float xfade = smoothstep(0, edgeFade, uvs.x)*smoothstep(1, 1-edgeFade, uvs.x);//Fade x uvs out towards the edges
		#endif
		float yfade = smoothstep(0, edgeFade, uvs.y)*smoothstep(1, 1-edgeFade, uvs.y);//Same for y
		float lengthFade = smoothstep(1, 0, 2*(totalSteps / maxSteps)-1);
	
		float fade = xfade * yfade * lengthFade;
	
		/*
		 * Get the color of the grabpass at the ray's screen uv location, applying
		 * an (expensive) blur effect to partially simulate roughness
		 * Second input for getBlurredGP is some math to make it so the max blurring
		 * occurs at 0.5 smoothness.
		 */
		float blurFactor = max(1,min(blur, blur * (-2)*(smoothness-1)));
		float4 reflection = float4(getBlurredGP(GrabTextureSSR, scrnParams, uvs.xy, blurFactor),1);
		
		reflection.a *= smoothness*reflStr*fade;
		
		
		/*
		 * If you're alpha-blending the reflection, then multiplying the alpha by the reflection
		 * strength and fade is enough. If you're adding the reflection, then you'll need to
		 * also multiply the color by those terms.
		 */
		//reflection.rgb = lerp(reflection.rgb, reflection.rgb*albedo.rgb,  rtint*metallic);
		reflection.rgb = lerp(reflection.rgb, reflection.rgb*albedo.rgb,  rtint*metallic)*reflStr*fade;
		
		
		reflection.a = lerp(0, reflection.a, fade)*(RdotV)*mask;
			
		return max(0,reflection); //sqrt(1 - saturate(uvs.y)));
	}	
}


/** @brief Gets the reflected color for a pixel
 *  
 *  Same as getSSRColor, but it takes the reflected rays direction instead of internally
 *  calculating the reflection direction. If you're getting the cubemap reflection, you'll
 *  have already calculated the same reflection direction elsewhere so it makes no sense to
 *  calculate it again.
 *
 *	@param wPos World position of the fragment
 *  @param viewDir World-space view direction of the fragment
 *  @param rayDir Reflected ray's world-space direction
 *  @param faceNormal Raw mesh normal direction
 *  @param largeRadius Large intersection radius for the ray (see reflect_ray())
 *  @param smallRadius Small intersection radius for the ray (see reflect_ray())
 *  @param stepSize initial step size for the ray (see reflect_ray())
 *  @param blur Square root of the max number of texture samples that can be taken to blur the grabpass
 *  @param maxSteps Max number of steps the ray can go
 *  @param isLowRes Only do SSR on 1 out of every 2x2 pixel block if 1, otherwise do on every pixel if 0
 *  @param smoothness Smoothness, determines how blurred the grabpass is, how scattered the rays are, and how strong the reflection is
 *  @param edgeFade How far off the edges of the screen the reflection gets faded out
 *  @param scrnParams width, height of screen in pixels (It is wise to use the zw components of the texel size of the grabpass for this,
 *		   unity's screen params give the wrong width for single pass stereo cameras)
 *  @param GrabTextureSSR Grabpass sampler
 *  @param NoiseTex Noise texture sampler
 *  @param NoiseTex_dim width/height of the noise texture
 *  @param albedo Albedo color of the pixel
 *  @param metallic How strongly the reflection color is influenced by the albedo color
 *  @param rtint Override for how metallic the surface is, not necessary, I should remove this.
 *  @param mask Mask for how strong the SSR is. Useful for making the SSR only affect certain parts of a material without making them less smooth
 *  @param reflStr Multiplier for how intense the SSR should be
 */

float4 getSSRColor2(
					const float4 wPos,
					const float3 viewDir,
					float4 rayDir,
					const half3 faceNormal,
					float largeRadius,
					float smallRadius,
					float stepSize,
					float blur,
					const int maxSteps,
					const int isLowRes,
					float smoothness,
					const float edgeFade,
					const float2 scrnParams,
					const sampler2D GrabTextureSSR,
					const sampler2D NoiseTex,
					const float2 NoiseTex_dim,
					float4 albedo,
					float metallic,
					float rtint,
					float mask,
					float reflStr
					)
{
	
	/*
	 * Calculate the cos of the angle between the view direction of the pixel and the reflected ray
	 * We'll use this later to skip raymarching if the reflected ray is coming back towards the camera
	 */
	float RdotV = dot(rayDir.xyz, viewDir);
	
	/*
	 * Calculate the cos of the angle between the surface (ignoring normal maps) and the reflected ray.
	 * We'll use this later to make sure the normal from the normal map didn't make us reflect a ray
	 * whose direction goes underneath the face it's reflecting off of.
	 */
	float FdotR = dot(faceNormal, rayDir.xyz);

	/*
	 * Calculate the screenspace position of the pixel for
	 * dithering. Note we can't use the same float4 for the
	 * final uv coordinates as the compiler will do some
	 * bad optimization that makes dithering loose its
	 * performance benefit entirely. Not sure why though.
	 */

	float4 screenUVs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos)));
	screenUVs.xy = screenUVs.xy / screenUVs.w;
	
	
	
	
	/*
	 * Read noise from a blue noise texture. We'll use this to randomly rotate/offset the ray and
	 * slightly change its speed to hide repeating artifacts like banding due to the step size
	 * and to fake blurring for lower smoothness surfaces by scattering the rays.
	 */
	float4 noiseUvs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos)));
	noiseUvs.xy = (noiseUvs.xy * scrnParams) / (NoiseTex_dim * noiseUvs.w);	
	//noiseUvs.xy = noiseUvs.xy/((scrnParams*NoiseTex_dim) * noiseUvs.w);	
	float4 noiseRGBA = tex2Dlod(NoiseTex, float4(noiseUvs.xy,0,0));
	float noise = noiseRGBA.r;
	
	
	/*
	 * Initially move the reflected ray forward a step. We need to move the ray forward enough that
	 * the ray will not hit the reflected surface's depth before it has a chance to move.
	 * This is an overestimate of how far the ray needs to move. Could be better, but I'm too lazy to
	 * do the math to get the smallest amount necessary.
	 */
	
	float4 reflectedRay = wPos + (largeRadius*stepSize/FdotR + noise*stepSize)*rayDir;
	
	// scatter rays based on roughness. WARNING. CAN BE EXTREMELY EXPENSIVE. RANDOM AND SPREAD OUT TEXTURE SAMPLES ARE VERY INEFFCIENT
	// YOU MAY WANT TO REMOVE THIS.
	float scatterMult = 0.2;
	float4 scatter = float4(0.5 - noiseRGBA.rgb,0);
	rayDir = normalize(rayDir + scatterMult*scatter*(1-smoothness)*sqrt(FdotR));
	
	/*
	 * If isLowRes is 1, only raymarch the pixels that have even x and y coordinates
	 * ie only do 1 out of every 2x2 block of pixels. This should save on performance.
	 */
	int dither = floor(fmod(scrnParams.x*screenUVs.x,2)) + floor(fmod(scrnParams.y*screenUVs.y,2));
	dither *= isLowRes;
	UNITY_BRANCH if (dither != 0) {
		return float4(0,0,0,0);
	}
	/*
	 * Don't raymarch if the ray is coming back towards the camera (RdotV < 0) or
	 * the ray is going into the surface (FdotR < 0).
	 * EDIT: don't do the RdotV check, rays coming back towards the camera can be useful
	 * in some cases
	 */

	else if (FdotR < 0)	//else if (FdotR < 0 || RdotV < 0)
	{
		return float4(0,0,0,0);
	}
	/*
	 * Begin the actual raymarching process
	 */
	else
	{
		

		
		/*
		 * Controls whether the ray is progressing forward or back along the ray
		 * path. Set to 1, the ray goes forward. Set to -1, the ray goes back.
		 */
		int back = 1;
		
		
		
		
		/*
		 * Do the raymarching against the depth texture. See SSR.cginc for the implementation of
		 * reflect_ray(). This returns a world-space position where the ray hit the depth texture,
		 * along with the number of iterations it took stored as the w component.
		 */
		
		float4 finalPos = reflect_ray(reflectedRay, rayDir, largeRadius, smallRadius, stepSize, noise, maxSteps);
		
		
		// get the total number of iterations out of finalPos's w component and replace with 1.
		float totalSteps = finalPos.w;
		finalPos.w = 1;
		
		/*
		 * A position of 0, 0, 0 signifies that the ray went off screen or ran
		 * out of iterations before actually hitting anything.
		 */
		if (finalPos.x == 0 && finalPos.y == 0 && finalPos.z == 0) 
		{
			return float4(0,0,0,0);
		}
		
		/*
		 * Get the screen space coordinates of the ray's final position
		 */
		float4 uvs;			
		uvs = UNITY_PROJ_COORD(ComputeGrabScreenPos(mul(UNITY_MATRIX_P, finalPos)));
		uvs.xy = uvs.xy / uvs.w;
					
		
	
	
	
		/*
		 * Fade towards the edges of the screen. If we're in VR, we can't really
		 * fade horizontally all that well as that results in stereo mismatch (the
		 * reflection will begin to fade in different locations in each eye). Thus
		 * just don't fade on X in VR. This isn't really a problem as we have tons
		 * of screen real estate that is not within the FOV of the headset and thus
		 * we can actually reflect some stuff that is technically off-screen.
		 */
		
		#if UNITY_SINGLE_PASS_STEREO
		float xfade = 1;
		#else
		float xfade = smoothstep(0, edgeFade, uvs.x)*smoothstep(1, 1-edgeFade, uvs.x);//Fade x uvs out towards the edges
		#endif
		float yfade = smoothstep(0, edgeFade, uvs.y)*smoothstep(1, 1-edgeFade, uvs.y);//Same for y
		float lengthFade = smoothstep(1, 0, 2*(totalSteps / maxSteps)-1);
	
		float fade = xfade * yfade * lengthFade;
	
		/*
		 * Get the color of the grabpass at the ray's screen uv location, applying
		 * an (expensive) blur effect to partially simulate roughness
		 * Second input for getBlurredGP is some math to make it so the max blurring
		 * occurs at 0.5 smoothness.
		 */
		float blurFactor = max(1,min(blur, blur * (-2)*(smoothness-1)));
		float4 reflection = float4(getBlurredGP(GrabTextureSSR, scrnParams, uvs.xy, blurFactor),1);
		
		reflection.a *= smoothness*reflStr*fade;
		
		
		/*
		 * If you're alpha-blending the reflection, then multiplying the alpha by the reflection
		 * strength and fade is enough. If you're adding the reflection, then you'll need to
		 * also multiply the color by those terms.
		 */
		//reflection.rgb = lerp(reflection.rgb, reflection.rgb*albedo.rgb,  rtint*metallic);
		reflection.rgb = lerp(reflection.rgb, reflection.rgb*albedo.rgb,  rtint*metallic)*reflStr*fade;
	
		
		
		reflection.a = lerp(0, reflection.a, fade)*(RdotV)*mask;
			
		return max(0,reflection); //sqrt(1 - saturate(uvs.y)));
	}	
}

