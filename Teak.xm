#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <math.h>

#define FF_BUNDLE   @"com.dts.freefireth"

static uintptr_t RVA_LOCAL_PLAYER   = 0x0;
static uintptr_t RVA_PLAYER_LIST    = 0x0;
static uintptr_t RVA_CAMERA         = 0x0;

static uintptr_t OFF_P_POSITION     = 0x0;
static uintptr_t OFF_P_AVATAR       = 0x0;
static uintptr_t OFF_P_TEAM         = 0x0;
static uintptr_t OFF_P_IS_LOCAL     = 0x0;

static uintptr_t OFF_A_BONES_ARRAY  = 0x14A4B0;
static uintptr_t OFF_C_VIEW_ANGLE   = 0x0;

static struct {
    bool   enabled;
    int    aimBone;
    float  aimOffsetY;
    float  aimSmooth;
    float  aimFov;
    float  maxDist;
} CFG = { .enabled=false, .aimBone=9, .aimOffsetY=0.07f, .aimSmooth=0.4f, .aimFov=100.0f, .maxDist=300.0f };

typedef struct { float x, y, z; } Vec3;
typedef struct { float pitch, yaw; } Vec2;

static uintptr_t g_lib_base = 0;
static uintptr_t lib_base(void) {
    if (g_lib_base) return g_lib_base;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && (strstr(name, "libil2cpp") || strstr(name, "FreeFire"))) {
            g_lib_base = _dyld_get_image_vmaddr_slide(i); return g_lib_base;
        }
    }
    return 0;
}
static inline uintptr_t rva(uintptr_t off) { uintptr_t b = lib_base(); return b ? (b + off) : 0; }
static bool sread(void *addr, void *out, size_t sz) {
    if (!addr || !out || !sz) return false;
    vm_size_t got = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)addr, sz, (vm_address_t)out, &got) == KERN_SUCCESS && got == sz;
}
static bool swrite(void *addr, const void *in, size_t sz) {
    if (!addr || !in || !sz) return false;
    return vm_write(mach_task_self(), (vm_address_t)addr, (vm_offset_t)in, sz) == KERN_SUCCESS;
}
static uintptr_t read_ptr(uintptr_t addr) { uintptr_t v = 0; sread((void*)addr, &v, sizeof(v)); return v & 0x0000000FFFFFFFFFULL; }
static Vec3 read_vec3(uintptr_t addr) { Vec3 v = {0}; sread((void*)addr, &v, sizeof(v)); return v; }
static Vec2 read_vec2(uintptr_t addr) { Vec2 v = {0}; sread((void*)addr, &v, sizeof(v)); return v; }
static void write_vec2(uintptr_t addr, Vec2 v) { swrite((void*)addr, &v, sizeof(v)); }
static float dist3(Vec3 a, Vec3 b) { float dx=a.x-b.x, dy=a.y-b.y, dz=a.z-b.z; return sqrtf(dx*dx+dy*dy+dz*dz); }

static uintptr_t get_local_player(void) { return RVA_LOCAL_PLAYER ? read_ptr(rva(RVA_LOCAL_PLAYER)) : 0; }
static uintptr_t get_player_list(void) { return RVA_PLAYER_LIST ? read_ptr(rva(RVA_PLAYER_LIST)) : 0; }
static Vec3 get_player_pos(uintptr_t p) { return (p && OFF_P_POSITION) ? read_vec3(p + OFF_P_POSITION) : (Vec3){0}; }
static int get_player_team(uintptr_t p) { int t=0; if(p && OFF_P_TEAM) sread((void*)(p+OFF_P_TEAM),&t,4); return t; }

static Vec3 get_neck_pos(uintptr_t player) {
    if (!player || !OFF_P_AVATAR || !OFF_A_BONES_ARRAY) return (Vec3){0};
    uintptr_t avatar = read_ptr(player + OFF_P_AVATAR); if (!avatar) return (Vec3){0};
    uintptr_t bones = read_ptr(avatar + OFF_A_BONES_ARRAY); if (!bones) return (Vec3){0};
    uintptr_t bone = read_ptr(bones + CFG.aimBone * 8); if (!bone) return (Vec3){0};
    Vec3 v = read_vec3(bone + 0x00); v.y += CFG.aimOffsetY; return v;
}

static uintptr_t find_nearest_enemy(Vec3 mypos, int myteam) {
    uintptr_t list = get_player_list(); if (!list) return 0;
    uintptr_t items = read_ptr(list + 0x10); int size = 0; sread((void*)(list + 0x18), &size, 4);
    if (!items || size <= 0 || size > 100) return 0;
    uintptr_t best = 0; float bestd = CFG.maxDist;
    for (int i = 0; i < size; i++) {
        uintptr_t p = read_ptr(items + i * 8); if (!p) continue;
        if (OFF_P_IS_LOCAL) { bool il = false; sread((void*)(p + OFF_P_IS_LOCAL), &il, 1); if (il) continue; }
        if (myteam > 0 && get_player_team(p) == myteam) continue;
        Vec3 pos = get_player_pos(p); if (pos.x==0 && pos.y==0 && pos.z==0) continue;
        float d = dist3(pos, mypos); if (d < bestd && d > 0.5f) { bestd = d; best = p; }
    }
    return best;
}

static void aim_at(uintptr_t target) {
    uintptr_t lp = get_local_player(); if (!lp || !target) return;
    Vec3 my = get_player_pos(lp); Vec3 neck = get_neck_pos(target);
    if (neck.x==0 && neck.y==0 && neck.z==0) return;
    float dx = neck.x-my.x, dy = neck.y-my.y, dz = neck.z-my.z;
    float yaw = atan2f(dy, dx) * 180.0f / M_PI;
    float pitch = atan2f(dz, sqrtf(dx*dx + dy*dy)) * 180.0f / M_PI;
    uintptr_t cam = RVA_CAMERA ? read_ptr(rva(RVA_CAMERA)) : 0;
    if (cam && OFF_C_VIEW_ANGLE) {
        Vec2 cur = read_vec2(cam + OFF_C_VIEW_ANGLE);
        float dyaw = fabsf(yaw - cur.yaw); if (dyaw > 180) dyaw = 360 - dyaw;
        if (dyaw > CFG.aimFov) return;
        float s = CFG.aimSmooth;
        Vec2 nv = { cur.pitch + (pitch - cur.pitch) * s, cur.yaw + (yaw - cur.yaw) * s };
        write_vec2(cam + OFF_C_VIEW_ANGLE, nv);
    }
}

static dispatch_source_t g_timer = NULL;
static void tick(v
