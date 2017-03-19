package require extend

extend ::dict {

  proc isDict {var} { 
    if { [::catch {::dict size ${var}}] } {::return 0} else {::return 1} 
  }
  
  proc get? {tempDict key args} {
    if {[::dict exists $tempDict $key {*}$args]} {
      ::return [::dict get $tempDict $key {*}$args]
    }
  }
  
  proc pull {var args} {
    ::upvar 1 $var check
    if { [::info exists check] } {
      ::set d $check
    } else { ::set d $var }
    ::foreach v $args {
      ::set path [::lassign $v variable name default]
      ::if { $name eq {} } { ::set name $variable }
      ::upvar 1 $name value
      ::if { [::dict exists $d {*}$path $variable] } {
        ::set value [::dict get $d {*}$path $variable]
      } else { ::set value $default }
      ::dict set rd $name $value
    }
    ::return $rd
  }
  
  proc pullFrom {var args} {
    ::set mpath [::lassign $var var]
    ::upvar 1 $var check
    ::if { [::info exists check] } { 
      ::set d $check
    } else { ::set d $var }
    ::foreach v $args {
      ::set path [::lassign $v variable name default]
      ::if { $name eq {} } { ::set name $variable }
      ::upvar 1 $name value
      ::if { [::dict exists $d {*}$mpath $variable {*}$path] } {
        ::set value [::dict get $d {*}$mpath $variable {*}$path]
      } else { ::set value $default }
      ::dict set rd $name $value
    }
    ::return $rd
  }
  
  proc modify {var args} {
    ::upvar 1 $var d
    ::if { ! [info exists d] } { ::set d {} }
    ::if { [::llength $args] == 1 } { ::set args [::lindex $args 0] }
    ::dict for { k v } $args { ::dict set d $k $v }
    ::return $d
  }
  
  proc push {var args} {
    ::if {$var ne "->"} { ::upvar 1 $var d }
    ::if { ! [::info exists d] } { ::set d {} }
    ::foreach arg $args {
      ::set default [::lassign $arg variable name]
      ::upvar 1 $variable value
      ::if { [::info exists value] } {
        ::if { $name eq {} } { ::set name $variable }
        ::if { $value ne {} } {
          ::dict set d $name $value
        } else { ::dict set d $name $default }
      } else { ::throw error "$variable doesn't exist when trying to push $name into dict $var" }
    }
    ::return $d
  }
  
  proc pushIf {var args} {
    ::if {$var ne "->"} { ::upvar 1 $var d }
    ::if { ! [::info exists d] } { ::set d {} }
    ::foreach arg $args {
      ::set default [::lassign $arg variable name]
      ::upvar 1 $variable value
      ::if { ! [::info exists value] } { ::throw error "$variable doesn't exist when trying to pushIf $name into dict $var" }
      ::if { $name eq {} } { ::set name $variable }
      ::if { $value ne {} } {
        ::dict set d $name $value
      } elseif { $default ne {} } {
        ::dict set d $name $default
      }
    }
    ::return $d
  }
  
  proc pushTo {var args} {
    ::set mpath [::lassign $var var]
    ::if {$var ne "->"} { ::upvar 1 $var d }
    ::if { ! [::info exists d] } { ::set d {} }
    ::foreach arg $args {
      ::set path [::lassign $arg variable name]
      ::upvar 1 $variable value
      ::if { ! [::info exists value] } { ::throw error "$variable doesn't exist when trying to pushTo $name into dict $var at path $path" }
      ::if { $name eq {} } { ::set name $variable }
      ::dict set d {*}$mpath {*}$path $name $value
    }
    ::return $d
  }

  proc destruct {var args} {
    ::set opVar [::lindex $var 0]
    ::set dArgs [::lrange $var 1 end]
    ::upvar 1 $opVar theDict
    ::if { ! [::info exists theDict] } {
      ::set theDict {}
    }
    ::set returnDict {}
    ::foreach val $args {
      ::lassign $val val nVar def
      ::if {$nVar eq ""} {::set nVar $val}
      ::upvar 1 $nVar $nVar
      ::if {$def ne ""} {
        ::set $nVar [::if? [::dict get? $theDict {*}$dArgs $val] $def]
      } else {
        ::set $nVar [::dict get? $theDict {*}$dArgs $val]
      }
      ::dict set returnDict $nVar [set $nVar]
      ::catch {::dict unset theDict {*}$dArgs $val}
    }
    ::return $returnDict
  }
  
  proc pickIf {var args} { ::return [::dict pick $var {*}$args] }
  
  proc pick {var args} {
    ::set tempDict {}
    ::foreach arg $args {
      ::lassign $arg key as
      ::if { [::dict exists $var $key] } {
        ::if { $as eq {} } { ::set as $key }
        ::set v [::dict get $var $key]
        ::if { $v ne {} } { ::dict set tempDict $as $v }
      }
    }
    ::return $tempDict
  }
  
  proc withKey {var key} {
    ::set tempDict {}
    ::dict for {k v} $var {
      ::if { [::dict exists $v $key] } {
        ::dict set tempDict $k [::dict get $v $key]	
      }
    }
    ::return $tempDict
  }
  
  ::proc fromlist { lst {values {}} } {
    ::set tempDict {}
    ::append tempDict [::join $lst " [list $values] "] " [list $values]"
  }
  
  proc sort {what dict args} {
    ::set res {}
    ::if {$dict eq {}} { ::return }
    ::set dictKeys [::dict keys $dict]
    ::switch -glob -nocase -- $what {
      "v*" {
        ::set valuePositions [::dict values $dict]
        ::foreach value [ ::lsort {*}$args [::dict values $dict] ] {
          ::set position       [::lsearch $valuePositions $value]
          ::if {$position eq -1} { ::puts stderr "Error for $value" }
          ::set key            [::lindex $dictKeys $position]
          ::set dictKeys       [::lreplace $dictKeys $position $position]
          ::set valuePositions [::lreplace $valuePositions $position $position]
          ::dict set res $key $value
        }
      }
      "k*" -
      default {
        ::foreach key [::lsort {*}$args $dictKeys] {
          ::dict set res $key [::dict get $dict $key] 
        }
      }
    }
    ::return $res
  }
  
  proc invert {var args} {
    ::set d {}
    ::dict for {k v} $var {
      ::if {"-overwrite" in $args} {
        ::dict set d $v $k
      } else {
        ::dict lappend d $v $k
      }
    }
    ::return $d
  }
  
  proc json {json dict {key {}}} {
    ::upvar 1 $dict convertFrom
    ::if {![info exists convertFrom] || $convertFrom eq {}} { ::return }
    ::set key [::if? $key $dict]
    $json map_key $key map_open
      ::dict for {k v} $convertFrom {
        ::if {$v eq {} || $k eq {}} { ::continue }
        ::if {[::string is entier -strict $v]} {   $json string $k number $v
        } elseif {[::string is bool -strict $v]} { $json string $k bool $v
        } else {                                   $json string $k string $v  
        }
      }
    $json map_close
    ::return
  }
  
  proc serialize { json dict } {
    ::dict for {k v} $dict {
      ::if {$v eq {} || $k eq {}} { ::continue }
      ::if {[::string is entier -strict $v]} {   $json string $k number $v
      } elseif {[::string is bool -strict $v]} { $json string $k bool $v
      } else {                                   $json string $k string $v  
      }
    }
  }
  
  proc types {tempDict} {
    ::set typeDict {}
    ::dict for {k v} $tempDict {
      ::if {[::string is entier -strict $v]} {     ::dict set typeDict $k number
        } elseif {[::string is bool -strict $v]} { ::dict set typeDict $k bool
        } else {                                   ::dict set typeDict $k string 
        }
    }
    ::return $typeDict
  }
}