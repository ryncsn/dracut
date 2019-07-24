/*
 * A small program that setup the squash mount and overlayfs mount without using libc.
 */
#define _GNU_SOURCE
#include "loader-helper.h"

#define LOOP_CONTROL "/dev/loop-control"
#define LOOP_DEVICE "/dev/loop0"
#define SQUASH_IMG "/squash/root.img"
#define SQUASH_ROOT "/squash/root"
#define SQUASH_PRELOAD_MODULES "/squash/preload-modules"
#define OVERLAY_WORKDIR "/squash/overlay_work"

#define GET_SQUASH_PATH(path) "/squash/root"path
#define GET_OVERLAY_WORKDIR(path) OVERLAY_WORKDIR path
#define GET_OVERLAY_OPT(path) "lowerdir=" GET_SQUASH_PATH(path) ",upperdir=" path ",workdir=" GET_OVERLAY_WORKDIR(path)

typedef struct MountPoint {
        const char *what;
        const char *where;
        const char *type;
        const char *options;
        unsigned long flags;

        const char *blob;
} MountPoint;

// TODO: Don't hardcode it
const char* preload_modules[] = {
        SQUASH_PRELOAD_MODULES"/loop.ko",
        SQUASH_PRELOAD_MODULES"/zstd_decompress.ko",
        SQUASH_PRELOAD_MODULES"/squashfs.ko",
        SQUASH_PRELOAD_MODULES"/overlay.ko",
        NULL
};

const char* init_args[] = {
        "/init.stock",
        NULL,
};

/*
 * Tricks to save some runtime memory.
 */
const char* init_envs[] = {
        "MALLOC_PERTURB_=0",
        "MALLOC_TOP_PAD_=0",
        NULL,
};

static const MountPoint mount_table[] = {
        { "sysfs",       "/sys",                      "sysfs",      NULL,                      MS_NOSUID|MS_NOEXEC|MS_NODEV },
        { "proc",        "/proc",                     "proc",       NULL,                      MS_NOSUID|MS_NOEXEC|MS_NODEV },
        { "devtmpfs",    "/dev",                      "devtmpfs",   "mode=755",                MS_NOSUID|MS_STRICTATIME },
};

static const MountPoint squash_table[] = {
        { LOOP_DEVICE,  "/squash/root",              "squashfs",   "ro,loop",                 0,       SQUASH_IMG},
};

// TODO: Redundant
static const MountPoint overlay_table[] = {
        { "overlay",     "/usr",                      "overlay",    GET_OVERLAY_OPT("/usr"),   0,       GET_OVERLAY_WORKDIR("/usr") },
        { "overlay",     "/etc",                      "overlay",    GET_OVERLAY_OPT("/etc"),   0,       GET_OVERLAY_WORKDIR("/etc")},
        { "overlay",     "/var",                      "overlay",    GET_OVERLAY_OPT("/var"),   0,       GET_OVERLAY_WORKDIR("/var")},
};

unsigned long long makedev (unsigned int __major, unsigned int __minor)
{
        return ((__minor & 0xff) | ((__major & 0xfff) << 8)
            | (((unsigned long long) (__minor & ~0xff)) << 12)
            | (((unsigned long long) (__major & ~0xfff)) << 32));
}

// TODO: Error checks in each step
int main() {
        int fd, sqsh_fd, i;
        const MountPoint *p;

        mkdir(SQUASH_ROOT, 0755);
        mkdir(OVERLAY_WORKDIR, 0755);

        for (int i = 0; preload_modules[i] ; ++i) {
                fd = open(preload_modules[i], O_RDONLY, 0);
                finit_module(fd, "", 0);
                close(fd);
                unlink(preload_modules[i]);
        }

        for (i = 0; i < sizeof(mount_table) / sizeof(MountPoint); i ++) {
                p = mount_table + i;

                mkdir(p->where, 0755);
                mount(p->what, p->where, p->type, p->flags, p->options);
        }

        for (i = 0; i < sizeof(squash_table) / sizeof(MountPoint); i ++) {
                p = squash_table + i;

                mkdir(p->where, 0755);
                fd = open(LOOP_CONTROL, O_RDWR|O_CLOEXEC, 0);

                ioctl(fd, LOOP_CTL_GET_FREE, NULL);

                sqsh_fd = open(p->blob, O_RDWR|O_CLOEXEC, 0);
                // TODO: Hardcoded loop0
                fd = open("/dev/loop0", O_RDWR|O_CLOEXEC, 0);

                struct loop_info64 loinfo = {
                        .lo_device = makedev(0, 0),
                        .lo_file_name = SQUASH_IMG,
                        .lo_encrypt_type = LO_CRYPT_NONE,
                        .lo_flags = LO_FLAGS_AUTOCLEAR,
                        .lo_crypt_name = "",
                        .lo_encrypt_key = "",
                        .lo_init = {0, 0},
                };

                ioctl(fd, LOOP_SET_FD, (void*) (long) sqsh_fd);
                ioctl(fd, LOOP_SET_STATUS64, &loinfo);

                mount(p->what, p->where, p->type, p->flags, p->options);

                fd = open("/sys/devices/virtual/block/loop0/queue/read_ahead_kb", O_RDWR, 0);
                write(fd, "0\n", 2);
                close(fd);

                mount(p->what, p->where, p->type, p->flags, p->options);
        }

        for (i = 0; i < sizeof(overlay_table) / sizeof(MountPoint); i ++) {
                p = overlay_table + i;

                mkdir(p->where, 0755);
                mkdir(p->blob, 0755);
                mount(p->what, p->where, p->type, p->flags, p->options);
        }

        execve(init_args[0], init_args, init_envs);

        return 0;
}

int _start() {
        int ret;
        ret = main();

        // Should not return as main will finally exec the real init, in case of return:
        // puts("ERROR: Failed  Error (%d)", ret);
        exit(1);

        return ret;
}
