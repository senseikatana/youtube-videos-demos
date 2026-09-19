#!/usr/bin/env zsh
# ==============================================
# 💻 VIRTUAL MACHINE MANAGEMENT
# ==============================================

on_virtmanager() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then 
        print -P "%F{cyan}Usage: virtmanager <create|run|full> [options]%f"
        print "  create <disk.qcow2> <size>              : Create a QCOW2 disk image (e.g. size: 20G)"
        print "  run <ram> <cpus> <disk> [iso] [vendor:prod] : Run VM (ram: 4G, cpus: 2, optional iso/usb)"
        print "  full <disk> <size> <ram> <cpus> [iso]   : Create and launch a VM in one step"
        print "  list                                     : List available VM images"
        return 0
    fi
    
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        print -P "%F{red}❌ Error: QEMU is not installed (qemu-system-x86_64 not found).%f"
        return 1
    fi
    
    local action="$1"
    shift
    
    case "$action" in
        create)
            local file="$1" size="$2"
            if [[ -z "$file" || -z "$size" ]]; then
                print "Usage: virtmanager create <disk.qcow2> <size (e.g. 20G)>"
                return 1
            fi
            if ! command -v qemu-img &>/dev/null; then
                print -P "%F{red}❌ Error: qemu-img utility not found.%f"
                return 1
            fi
            print -P "💾 Creating disk image: ${C_CYAN}$file${C_RESET} (${C_YELLOW}$size${C_RESET})"
            qemu-img create -f qcow2 "$file" "$size"
            ;;
        run)
            local ram="$1" cpus="$2" disco="$3" iso="$4" usb="$5"
            if [[ -z "$ram" || -z "$cpus" || -z "$disco" ]]; then
                print "Usage: virtmanager run <RAM> <CPUs> <disk.qcow2> [iso_file] [usb_vendor:product]"
                return 1
            fi
            if [[ ! -f "$disco" ]]; then
                print -P "%F{red}❌ Error: Disk image '$disco' not found.%f"
                return 1
            fi
            
            print -P "🚀 Starting VM with ${C_YELLOW}$ram${C_RESET} RAM, ${C_YELLOW}$cpus${C_RESET} CPUs"
            
            local kvm=(-cpu qemu64)
            if [[ -w /dev/kvm ]]; then
                kvm=(-enable-kvm -cpu host)
                print -P "✅ KVM acceleration enabled"
            fi
            
            local usb_args=(-device qemu-xhci)
            if [[ -n "$usb" ]]; then 
                local v="${usb%:*}" p="${usb#*:}"
                usb_args=(-device qemu-xhci,id=usb -device usb-host,vendorid=0x$v,productid=0x$p)
                print -P "🔌 USB passthrough: vendor=${C_CYAN}$v${C_RESET}, product=${C_CYAN}$p${C_RESET}"
            fi
            
            local args=(qemu-system-x86_64 -M q35 "${kvm[@]}" -m "$ram" -smp "$cpus" \
                -drive file="$disco",format=qcow2 -netdev user,id=net -device e1000,netdev=net \
                -vga std "${usb_args[@]}" -device usb-tablet)
            
            if [[ -n "$iso" && -f "$iso" ]]; then 
                args+=(-cdrom "$iso" -boot d)
                print -P "💿 Boot from ISO: ${C_CYAN}$iso${C_RESET}"
            else 
                args+=(-boot c)
                print -P "💾 Boot from disk"
            fi
            
            print -P "🖥️  Starting QEMU... (Ctrl+C to exit)"
            if [[ -n "$usb" ]]; then 
                sudo "${args[@]}"
            else 
                "${args[@]}"
            fi
            ;;
        full)
            local file="$1" size="$2" ram="$3" cpus="$4" iso="$5"
            if [[ -z "$file" || -z "$size" || -z "$ram" || -z "$cpus" ]]; then
                print "Usage: virtmanager full <disk.qcow2> <size> <RAM> <CPUs> [iso]"
                return 1
            fi
            print -P "${C_GREEN}🚀 Creating and launching VM in one step...${C_RESET}"
            virtmanager create "$file" "$size" && virtmanager run "$ram" "$cpus" "$file" "$iso"
            ;;
        list)
            print -P "${C_CYAN}📂 Available VM images:${C_RESET}"
            ls -la *.qcow2 2>/dev/null || echo "No qcow2 images found in current directory"
            ;;
        *)
            print -P "%F{red}❌ Error: Invalid action. Supported actions: create, run, full, list%f"
            return 1
            ;;
    esac
}


