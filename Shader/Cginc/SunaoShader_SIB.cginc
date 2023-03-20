//--------------------------------------------------------------
//              Sunao Shader Space in body
//                      Copyright (c) 2022 てみず
//--------------------------------------------------------------


#include "UnityCG.cginc"
#include "Lighting.cginc"
#define PI 3.141592653589793

float _SIB_transX;
float _SIB_transY;
float _SIB_transZ;
float _SIB_rotateX;
float _SIB_rotateY;
float _SIB_rotateZ;
float4 _SIB_EnvironmentLightColor;
float _SIB_RenderingAccuracyA;
int _SIB_RenderingAccuracyB;
float _SIB_RenderingDistance;
float _SIB_SplitLevelA;
float _SIB_SplitLevelB;

float _trans_x = 0;
float _trans_y = 0;
float _trans_z = 0;
float _rotate_x = 0;
float _rotate_y = 0;
float _rotate_z = 0;
float _r = 0.22;
float _g = 0;
float _b = 0.413;
float _dlevel = 0.001;
float _k = 1.08;
float _sbunbo = 5.17;

float2 rot(float2 p,float r) {//回転のための関数
	r = r * PI / 180;
	float2x2 rotation = float2x2(cos(r),sin(r),-sin(r),cos(r));
	return mul(p, rotation);
}


float cube(float3 p, float s) {
	float3 m = float3(s,s,s) - abs(p);
	return min(min(-min(m.x, m.y), -min(m.z,m.y)),-min(m.x,m.z));
}

float menger(float3 p) {
	float d = 0;
	float k = _SIB_SplitLevelA;
	float s = 1.0 / _SIB_SplitLevelB;
	for (int i = 0; i < 5; i++) {
		d = max(d,-cube(abs(fmod(p - (k / 2.0), k)) - 0.5 * k, s));
		k /= 4.0;
		s /= 4.0;
	}
	return d;
}

float2 pmod(float2 p,float n) {
	float np = PI * 2.0 / n;
	float r = atan2(p.x,p.y) - 0.5 * np;
	r = abs(fmod(r,np)) - 0.5 * np;
	return length(p) * float2(cos(r),sin(r));
}


float dist(float3 p) {//最終的な距離関数
	
	float3 trans = float3(_SIB_transX, _SIB_transY, _SIB_transZ);
	p.xy = rot(p.xy, _SIB_rotateZ);
	p.xz = rot(p.xz, _SIB_rotateY);
	p.yz = rot(p.yz, _SIB_rotateX);
	
	float momo = 4.0;
	p *= momo;
	p.y -= 0.2;
	p.xy = pmod(p.xy,8.0);
	p.x -= -0.1;
	return  menger(p-trans)/momo;
}

float3 getnormal(float3 p)//法線を導出する関数
{
	float d = 0.0001;
	return normalize(float3(
	dist(p + float3(d, 0.0, 0.0)) - dist(p + float3(-d, 0.0, 0.0)),
	dist(p + float3(0.0, d, 0.0)) - dist(p + float3(0.0, -d, 0.0)),
	dist(p + float3(0.0, 0.0, d)) - dist(p + float3(0.0, 0.0, -d))
	));
}

struct appdata
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
};

struct v2f
{
	float2 uv : TEXCOORD0;
	float3 pos : TEXCOORD1;
	float4 grabPos : TEXCOORD2;
	half depth : TEXCOORD3;
	float4 vertex : SV_POSITION;
};

struct pout
{
	fixed4 color : SV_Target;
	float depth : SV_Depth;
};
sampler2D _sonomama; 
v2f vert (appdata v)
{
	v2f o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.pos = v.vertex.xyz;
	o.grabPos = ComputeGrabScreenPos(o.vertex);
	COMPUTE_EYEDEPTH(o.depth.x);
	o.uv = o.pos.xy / o.pos.z * _ScreenParams.xy;
	return o;
}

pout frag(v2f i, fixed facing : VFACE) : SV_Target
{
	float3 localcamerapos =  mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1)).xyz;
	float mesh_to_camera_distance = length(i.pos.xyz - localcamerapos);
	pout o;
	if(facing > 0 || mesh_to_camera_distance > _SIB_RenderingDistance){
		o.color = tex2Dproj(_sonomama, i.grabPos); 
		o.depth = i.depth.x;
		return o;
	}
	
	//以下、ローカル座標で話が進む
	float3 ro = localcamerapos;//レイのスタート位置をカメラのローカル座標とする
	float3 rd = normalize(i.pos.xyz - ro);//メッシュのローカル座標の、視点のローカル座標からの方向を求めることでレイの方向を定義

	float d = 0;
	float t = 0;
	float3 p = float3(0, 0, 0);
	float ikiti = pow(0.1, _SIB_RenderingAccuracyA);
	for (int i = 0; i < _SIB_RenderingAccuracyB; ++i) { 
		p = ro + rd * t;
		d = dist(p);
		t += d;
		//if(t < 0.1 && d > 0.001) continue;

		if (d < ikiti || t>30)break;
	}
	p = ro + rd * t;
	fixed4 col = float4(0,0,0,1);
	if (d >= ikiti || t < 0.01) { 
		//discard;
	}
	else {
		float3 lightDir = localcamerapos;
		float3 normal = getnormal(p);
		float3 lightColor = float3(1,1,1);
		col = fixed4(lightColor * max(dot(normal, lightDir), 0) , 1.0);
		col.rgb += _SIB_EnvironmentLightColor.xyz/2;//fixed3(0.22, 0, 0.413);//環境光

	}
	col.rgb += _SIB_EnvironmentLightColor.xyz/2;//fixed3(0.22, 0, 0.413);//環境光

	o.color = col;
	float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
	o.depth = projectionPos.z / projectionPos.w;
	
	return o;
}
