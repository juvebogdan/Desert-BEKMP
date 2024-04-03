#
# Copyright (c) 2015 Regents of the SIGNET lab, University of Padova.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University of Padova (SIGNET lab) nor the 
#    names of its contributors may be used to endorse or promote products 
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; 
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Author: Giovanni Toso <tosogiov@dei.unipd.it>
# Version: 1.0.0
# NOTE: tcl sample tested on Ubuntu 12.04, 64 bits OS
#
#########################################################################################
##
## NOTE: This script uses the PHY model "Module/MPhy/BPSK" of NS-Miracle in addPosition
## with the module "MInterference/MIV" for the computation of interference. 
## These two modules is used in this script to demonstrate their compatibility with
## DESERT stack.
## If you decide to use Module/UW/PHYSICAL from DESERT, it is suggested to use also 
## Module/UW/INTERFERENCE (which is an extension of the one coming from NS-Miracle)
## Anyways, it is possibile to use Module/UW/INTERFERENCE with Module/MPhy/BPSK whereas
## it is not possibile to use MInterference/MIV with Module/UW/INTERFERENCE for compatibility
## reasons
##
########################################################################################
# ----------------------------------------------------------------------------------
# This script depicts a very simple but complete stack in which two nodes send data
# to a common sink. The second node is used by the first one as a relay to send data to the sink.
# The routes are configured by using UW/STATICROUTING.
# The application used to generate data is UW/CBR.
# ----------------------------------------------------------------------------------
# Stack
#             Node 1                         Node 2                        Sink
#   +--------------------------+   +--------------------------+   +-------------+------------+
#   |  7. UW/CBR               |   |  7. UW/CBR               |   |  7. UW/CBR  | UW/CBR     |
#   +--------------------------+   +--------------------------+   +-------------+------------+
#   |  6. UW/UDP               |   |  6. UW/UDP               |   |  6. UW/UDP               |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  5. UW/STATICROUTING     |   |  5. UW/STATICROUTING     |   |  5. UW/STATICROUTING     |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  4. UW/IP                |   |  4. UW/IP                |   |  4. UW/IP                |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  3. UW/MLL               |   |  3. UW/MLL               |   |  3. UW/MLL               |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  2. UW/CSMA_ALOHA        |   |  2. UW/CSMA_ALOHA        |   |  2. UW/CSMA_ALOHA        |
#   +--------------------------+   +--------------------------+   +--------------------------+
#   |  1. Module/MPhy/BPSK     |   |  1. Module/MPhy/BPSK     |   |  1. Module/MPhy/BPSK     |
#   +--------------------------+   +--------------------------+   +--------------------------+
#            |         |                    |         |                   |         |       
#   +----------------------------------------------------------------------------------------+
#   |                                     UnderwaterChannel                                  |
#   +----------------------------------------------------------------------------------------+

######################################
# Flags to enable or disable options #
######################################
set opt(trace_files)        0
set opt(bash_parameters)    0

#####################
# Library Loading   #
#####################
load libMiracle.so
load libMiracleBasicMovement.so
load libmphy.so
load libmmac.so
load libuwmmac_clmsgs.so
load libuwphy_clmsgs.so
load libUwmStd.so
load libuwcsmaaloha.so
load libuwip.so
load libuwstaticrouting.so
load libuwmll.so
load libuwudp.so
load libuwcbr.so
load libuwsink.so
load libuwinterference.so
load libUwmStdPhyBpskTracer.so
load libuwphy_clmsgs.so
load libuwstats_utilities.so
load libuwphysical.so
load libuwdriftposition.so
load libuwflooding.so

# Specify the directory to search for files. Use "." for the current directory
set directory "."

# Use the glob command with -nocomplain to find all files starting with "tracefile"
# in the specified directory. If no files match, an empty list is returned.
set files [glob -nocomplain -directory $directory "tracefile*"]

# Iterate over each file in the list and delete them
foreach file $files {
    file delete $file
}

#############################
# NS-Miracle initialization #
#############################
# You always need the following two lines to use the NS-Miracle simulator
set ns [new Simulator]
$ns use-Miracle

##################
# Tcl variables  #
##################
set opt(nn)                 6.0 ;# Number of Nodes
set opt(nsink)                 3.0 ;# Number of Nodes
set opt(starttime)          1
set opt(starttime2)         5
set opt(stoptime)           100000
set opt(txduration)         [expr $opt(stoptime) - $opt(starttime)]

set opt(maxinterval_)       20.0
set opt(freq)               24000.0; #ide 24-32kHz
set opt(bw)                 5000.0
set opt(bitrate)            640.0
set opt(ack_mode)           "setAckMode"

set opt(txpower)            160
set opt(rngstream)	        10
set opt(pktsize)            64
set opt(cbr_period)         60
set opt(protocol)           2

global defaultRNG
for {set k 0} {$k < $opt(rngstream)} {incr k} {
	$defaultRNG next-substream
}

if {$opt(trace_files)} {
    set opt(tracefilename) "./test_uwcbr.tr"
    set opt(tracefile) [open $opt(tracefilename) w]
    set opt(cltracefilename) "./test_uwcbr.cltr"
    set opt(cltracefile) [open $opt(tracefilename) w]
} else {
    set opt(tracefilename) "/dev/null"
    set opt(tracefile) [open $opt(tracefilename) w]
    set opt(cltracefilename) "/dev/null"
    set opt(cltracefile) [open $opt(cltracefilename) w]
}

# ### Channel ###
# MPropagation/Underwater set practicalSpreading_ 2
# MPropagation/Underwater set debug_              0
# MPropagation/Underwater set windspeed_          3
# MPropagation/Underwater set shipping_           1

#########################
# Command line options  #
#########################
set channel [new Module/UnderwaterChannel]
set propagation [new MPropagation/Underwater]
set data_mask [new MSpectralMask/Rect]
$data_mask setFreq       $opt(freq)
$data_mask setBandwidth  $opt(bw)

#########################
# Module Configuration  #
#########################
#UW/CBR
Module/UW/CBR set packetSize_          $opt(pktsize)
Module/UW/CBR set period_              $opt(cbr_period)
Module/UW/CBR set PoissonTraffic_      1
Module/UW/CBR set debug_              0
Module/UW/CBR set tracefile_enabler_  1
Module/UW/CBR set traffic_type_		  5
if {$opt(protocol) == 1} {
    Module/UW/CBR set authSize 8
} elseif {$opt(protocol) == 2} {
    Module/UW/CBR set authSize 100
}


#FLOODING
Module/UW/FLOODING set ttl_                       1
Module/UW/FLOODING set maximum_cache_time__time_  $opt(stoptime)

################################
# Procedure(s) to create nodes #
################################
proc createNode { id } {

    global channel propagation data_mask ns cbr position node udp portnum ipr ipif
    global phy posdb opt rvposx mll mac db_manager
    global node_coordinates defaultRNG
    
    set node($id) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)] 

    ## Physical
    Module/UW/PHYSICAL  set TxPower_         $opt(txpower)
    Module/UW/PHYSICAL  set BitRate_                    $opt(bitrate)
    # Module/UW/PHYSICAL  set AcquisitionThreshold_dB_    15.0 
    # Module/UW/PHYSICAL  set RxSnrPenalty_dB_            0
    # Module/UW/PHYSICAL  set TxSPLMargin_dB_             0
    Module/UW/PHYSICAL  set MaxTxSPL_dB_                $opt(txpower)
    # Module/UW/PHYSICAL  set MinTxSPL_dB_                10
    Module/UW/PHYSICAL  set MaxTxRange_                 200
    # Module/UW/PHYSICAL  set PER_target_                 0    
    # Module/UW/PHYSICAL  set CentralFreqOptimization_    0
    # Module/UW/PHYSICAL  set BandwidthOptimization_      0
    # Module/UW/PHYSICAL  set SPLOptimization_            0
    Module/UW/PHYSICAL  set debug_                      0

    set cbr($id)  [new Module/UW/CBR] 
    set udp($id)  [new Module/UW/UDP]
    set ipr($id)  [new Module/UW/FLOODING]
    set ipif($id) [new Module/UW/IP]
    set mll($id)  [new Module/UW/MLL] 
    set mac($id)  [new Module/UW/CSMA_ALOHA] 
    set phy($id)  [new Module/UW/PHYSICAL]

    $node($id) addModule 7 $cbr($id)   0  "CBR"
    $node($id) addModule 6 $udp($id)   0  "UDP"
    $node($id) addModule 5 $ipr($id)   0  "IPR"
    $node($id) addModule 4 $ipif($id)  0  "IPF"   
    $node($id) addModule 3 $mll($id)   0  "MLL"
    $node($id) addModule 2 $mac($id)   0  "MAC"
    $node($id) addModule 1 $phy($id)   0  "PHY"

    $node($id) setConnection $cbr($id)   $udp($id)   0
    $cbr($id) "setLogSuffix" "node$id"
    $node($id) setConnection $udp($id)   $ipr($id)   0
    $node($id) setConnection $ipr($id)   $ipif($id)  0
    $node($id) setConnection $ipif($id)  $mll($id)   0
    $node($id) setConnection $mll($id)   $mac($id)   0
    $node($id) setConnection $mac($id)   $phy($id)   0
    $node($id) addToChannel  $channel    $phy($id)   0

    set portnum($id) [$udp($id) assignPort $cbr($id) ]
    puts "SEt node port $portnum($id)"
    if {$id > 254} {
    puts "hostnum > 254!!! exiting"
    exit
    }
    set tmp_ [expr ($id) + 1]
    $ipif($id) addr $tmp_
    $ipr($id) addr $tmp_

    # UWDRIFTPOSITION
    Position/UWDRIFT set boundx_               1;      # 0 no bounds, 1 yes
    Position/UWDRIFT set boundy_               1
    Position/UWDRIFT set boundz_               1
    Position/UWDRIFT set xFieldWidth_	   2000;  # The module uses these values only if the corrispective bound is set to 1, in meters
    Position/UWDRIFT set yFieldWidth_	   2000
    Position/UWDRIFT set zFieldWidth_	   600
    Position/UWDRIFT set speed_horizontal_     0.3;       # Horizontal component of the speed, in m/s. 0 means no constant horizontal speed = completely random
    Position/UWDRIFT set speed_longitudinal_   0.3;
    Position/UWDRIFT set speed_vertical_       0.3;
    Position/UWDRIFT set alpha_	           0.7
    Position/UWDRIFT set deltax_               1.5      
    Position/UWDRIFT set deltay_               1.5
    Position/UWDRIFT set deltaz_               1.5
    Position/UWDRIFT set starting_speed_x_     0
    Position/UWDRIFT set starting_speed_y_     0
    Position/UWDRIFT set starting_speed_z_     0
    Position/UWDRIFT set updateTime_	   10;      # In seconds
    Position/UWDRIFT set debug_		   0
    Position/UWDRIFT set nodeid		   $id
    Position/UWDRIFT set tracefile_enabler_  1

    set position($id) [new "Position/UWDRIFT"]
    $node($id) addPosition $position($id)
    set posdb($id) [new "PlugIn/PositionDB"]
    $node($id) addPlugin $posdb($id) 20 "PDB"
    $posdb($id) addpos [$mac($id) addr] $position($id)
    
    set interf_data($id) [new "Module/UW/INTERFERENCE"]
    $interf_data($id) set maxinterval_ $opt(maxinterval_)
    $interf_data($id) set debug_       0

    $phy($id) setPropagation $propagation
    
    $phy($id) setSpectralMask $data_mask
    $phy($id) setInterference $interf_data($id)
    $mac($id) $opt(ack_mode)
    $mac($id) initialize
}

proc createSink { id1 } {

    global channel propagation smask data_mask ns cbr_sink position_sink node_sink udp_sink portnum_sink interf_data_sink
    global phy_data_sink posdb_sink opt mll_sink mac_sink ipr_sink ipif_sink bpsk interf_sink defaultRNG

    set node_sink($id1) [$ns create-M_Node $opt(tracefile) $opt(cltracefile)]

    #UW/SINK
    Module/UW/SINK set packetSize_          $opt(pktsize)
    Module/UW/SINK set period_              $opt(cbr_period)
    Module/UW/SINK set PoissonTraffic_      0
    Module/UW/SINK set debug_              0
    Module/UW/SINK set Sinkid              $id1
    Module/UW/SINK set tracefile_enabler_  1
    Module/UW/SINK set keyExpiry  600
    Module/UW/SINK set reAuthExpiry  50
    if {$opt(protocol) == 1} {
        Module/UW/SINK set authResponseSize 48
    } elseif {$opt(protocol) == 2} {
        Module/UW/SINK set authResponseSize 96
    }

    ## Physical
    Module/UW/PHYSICAL  set TxPower_         $opt(txpower)
    Module/UW/PHYSICAL  set BitRate_                    $opt(bitrate)
    # Module/UW/PHYSICAL  set AcquisitionThreshold_dB_    15.0 
    # Module/UW/PHYSICAL  set RxSnrPenalty_dB_            0
    # Module/UW/PHYSICAL  set TxSPLMargin_dB_             0
    Module/UW/PHYSICAL  set MaxTxSPL_dB_                $opt(txpower)
    # Module/UW/PHYSICAL  set MinTxSPL_dB_                10
    Module/UW/PHYSICAL  set MaxTxRange_                 200
    # Module/UW/PHYSICAL  set PER_target_                 0    
    # Module/UW/PHYSICAL  set CentralFreqOptimization_    0
    # Module/UW/PHYSICAL  set BandwidthOptimization_      0
    # Module/UW/PHYSICAL  set SPLOptimization_            0
    Module/UW/PHYSICAL  set debug_                      0

    for {set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set key "$id1, ${cnt}"
        set cbr_sink($key)  [new Module/UW/SINK] 
    }
    set udp_sink($id1)       [new Module/UW/UDP]
    set ipr_sink($id1)       [new Module/UW/FLOODING]
    set ipif_sink($id1)      [new Module/UW/IP]
    set mll_sink($id1)       [new Module/UW/MLL] 
    set mac_sink($id1)       [new Module/UW/CSMA_ALOHA]
    set phy_data_sink($id1)  [new Module/UW/PHYSICAL] 

    for { set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set key "$id1, ${cnt}"
        $node_sink($id1) addModule 7 $cbr_sink($key) 0 "CBR"
    }
    $node_sink($id1) addModule 6 $udp_sink($id1)       0 "UDP"
    $node_sink($id1) addModule 5 $ipr_sink($id1)       0 "IPR"
    $node_sink($id1) addModule 4 $ipif_sink($id1)      0 "IPF"   
    $node_sink($id1) addModule 3 $mll_sink($id1)       0 "MLL"
    $node_sink($id1) addModule 2 $mac_sink($id1)       0 "MAC"
    $node_sink($id1) addModule 1 $phy_data_sink($id1)  0 "PHY"

    for { set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set key "$id1, ${cnt}"
        $node_sink($id1) setConnection $cbr_sink($key)  $udp_sink($id1)      0   
        $cbr_sink($key) "setLogSuffix" "sink$key"
    }
    $node_sink($id1) setConnection $udp_sink($id1)  $ipr_sink($id1)            0
    $node_sink($id1) setConnection $ipr_sink($id1)  $ipif_sink($id1)           0
    $node_sink($id1) setConnection $ipif_sink($id1) $mll_sink($id1)            0 
    $node_sink($id1) setConnection $mll_sink($id1)  $mac_sink($id1)            0
    $node_sink($id1) setConnection $mac_sink($id1)  $phy_data_sink($id1)       0
    $node_sink($id1) addToChannel  $channel   $phy_data_sink($id1)       0

    for { set cnt 0} {$cnt < $opt(nn)} {incr cnt} {
        set key "$id1, ${cnt}"
        set portnum_sink($key) [$udp_sink($id1) assignPort $cbr_sink($key)]    
    }

    set tmp_ [expr 254 - $id1]
    $ipif_sink($id1) addr $tmp_
    $ipr_sink($id1) addr $tmp_

    set position_sink($id1) [new "Position/BM"]
    $node_sink($id1) addPosition $position_sink($id1)
    set posdb_sink($id1) [new "PlugIn/PositionDB"]
    $node_sink($id1) addPlugin $posdb_sink($id1) 20 "PDB"
    $posdb_sink($id1) addpos [$mac_sink($id1) addr] $position_sink($id1)

    set interf_data_sink($id1) [new "Module/UW/INTERFERENCE"]
    $interf_data_sink($id1) set maxinterval_ $opt(maxinterval_)
    $interf_data_sink($id1) set debug_       0

    $phy_data_sink($id1) setSpectralMask $data_mask
    $phy_data_sink($id1) setInterference $interf_data_sink($id1)
    $phy_data_sink($id1) setPropagation $propagation

    $mac_sink($id1) $opt(ack_mode)
    $mac_sink($id1) initialize
}


#################
# Node Creation #
#################
# Create here all the nodes you want to network together
for {set id 0} {$id < $opt(nn)} {incr id}  {
    createNode $id
}
for {set id 0} {$id < $opt(nsink)} {incr id}  {
    createSink $id
}

################################
# Inter-node module connection #
################################
proc connectNodes {id1} {
    global ipif ipr portnum cbr cbr_sink ipif_sink portnum_sink ipr_sink cbr_sink2 ipif_sink2 portnum_sink2 ipr_sink2 cbr_sink3 ipif_sink3 portnum_sink3 ipr_sink3 opt

    $cbr($id1) set destAddr_ 255
    for {set id 0} {$id < $opt(nsink)} {incr id}  {
        set key "$id, $id1"
        $cbr($id1) set destPort_ $portnum_sink($key)
    }
    # $cbr($id1) set destPort_ $portnum_sink2($id1)
    # $cbr($id1) set destPort_ $portnum_sink3($id1)

    for {set id 0} {$id < $opt(nsink)} {incr id}  {
        set key "$id, ${id1}"
        $cbr_sink($key) set destAddr_ 255
        $cbr_sink($key) set destPort_ $portnum($id1)
    }
}

# Setup flows
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    connectNodes $id1
}

# Fill ARP tables
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    # for {set id2 0} {$id2 < $opt(nn)} {incr id2}  {
    #   $mll($id1) addentry [$ipif($id2) addr] [$mac($id2) addr]
    # }  
    for {set id 0} {$id < $opt(nsink)} {incr id}  {
        $mll($id1) addentry [$ipif_sink($id) addr] [ $mac_sink($id) addr]
        $mll_sink($id) addentry [$ipif($id1) addr] [ $mac($id1) addr]
    } 
    # $mll($id1) addentry [$ipif_sink2 addr] [ $mac_sink2 addr]
    # $mll($id1) addentry [$ipif_sink3 addr] [ $mac_sink3 addr]
    # $mll_sink2 addentry [$ipif($id1) addr] [ $mac($id1) addr]
    # $mll_sink3 addentry [$ipif($id1) addr] [ $mac($id1) addr]
}

# Setup positions
# for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
#     $position($id1) setX_ [expr 50 * $id1]
#     $position($id1) setY_ [expr 50 * $id1]
#     $position($id1) setZ_ -5
# }
# for {set id1 0} {$id1 < $opt(nsink)} {incr id1}  {
#     $position_sink($id1) setX_ [expr 50 * $id1]
#     $position_sink($id1) setY_ [expr 50 * $id1]
#     $position_sink($id1) setZ_ [expr -100 * $id1]
# }
for {set id1 0} {$id1 < $opt(nn)} {incr id1} {
    # Generate random X, Y coordinates within the 2000x2000 area
    set randX [expr {int(rand() * 2000)}]
    set randY [expr {int(rand() * 2000)}]
    
    # Generate random Z coordinate (depth) within the -2000 to 0 range
    # Since it's for depth and should be negative, subtract from 0
    set randZ [expr {-1 * int(rand() * 600)}]

    # Set the position for the current node
    $position($id1) setX_ $randX
    $position($id1) setY_ $randY
    $position($id1) setZ_ $randZ

    puts "Node $id1 Position: X = $randX, Y = $randY, Z = $randZ"
}
# #node
# $position(0) setX_ [expr 1000]
# $position(0) setY_ [expr 333]
# $position(0) setZ_ -100
#Sink 1 254
$position_sink(0) setX_ [expr 1000]
$position_sink(0) setY_ [expr 333]
$position_sink(0) setZ_ [expr 0]
#Sink 2 253
$position_sink(1) setX_ [expr 666]
$position_sink(1) setY_ [expr 1666]
$position_sink(1) setZ_ [expr 0]
#Sink 3 252
$position_sink(2) setX_ [expr 1333]
$position_sink(2) setY_ [expr 1666]
$position_sink(2) setZ_ [expr 0]

# Setup routing table
# for {set id1 0} {$id1 < [expr $opt(nn)]} {incr id1}  {
#     #$ipr($id1) addRoute [$ipif_sink addr] [$ipif_sink addr]
#     $ipr_sink addRoute [$ipif($id1) addr] [$ipif($id1) addr]
# }


#####################
# Start/Stop Timers #
#####################
# Set here the timers to start and/or stop modules (optional)
# e.g., 
for {set id1 0} {$id1 < $opt(nn)} {incr id1}  {
    $ns at $opt(starttime)    "$cbr($id1) start"
    $ns at $opt(stoptime)     "$cbr($id1) stop"
}

###################
# Final Procedure #
###################
# Define here the procedure to call at the end of the simulation
proc finish {} {
    exec redis-cli FLUSHALL
    global ns opt
    global mac propagation cbr_sink mac_sink phy_data phy_data_sink channel db_manager propagation cbr_sink2 mac_sink2 phy_data_sink2 cbr_sink3 mac_sink3 phy_data_sink3
    global node_coordinates
    global ipr_sink ipr ipif udp cbr phy phy_data_sink ipr_sink2
    global node_stats tmp_node_stats sink_stats tmp_sink_stats

    puts "---------------------------------------------------------------------"
    puts "Simulation summary"
    puts "number of nodes  : $opt(nn)"
    puts "packet size      : $opt(pktsize) byte"
    puts "cbr period       : $opt(cbr_period) s"
    puts "number of nodes  : $opt(nn)"
    puts "simulation length: $opt(txduration) s"
    puts "tx frequency     : $opt(freq) Hz"
    puts "tx bandwidth     : $opt(bw) Hz"
    puts "bitrate          : $opt(bitrate) bps"
    puts "---------------------------------------------------------------------"

    #set sum_cbr_throughput     0
    set sum_per                0
    set sum_cbr_sent_pkts      0.0
    set sum_cbr_rcv_pkts       0.0 
    set sum_consumed_energy_tx 0.0
    set sum_consumed_energy_rx 0.0
    set sum_cross_connections 0
    set sum_auth_connections 0
    set sum_cbr_1_rcv_pkts       [$cbr(0) getrecvpkts]    
    set average_per 0

    for {set j 0} {$j < $opt(nsink)} {incr j}  {
        set sum_cbr_throughput($j)     0
        for {set i 0} {$i < $opt(nn)} {incr i}  {
            set key "$j, ${i}"
            set cbr_rcv_pkts           [$cbr_sink($key) getrecvpkts]
            set sum_cbr_rcv_pkts   [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
            set cbr_throughput           [$cbr_sink($key) getthr]
            set sum_cbr_throughput($j) [expr $sum_cbr_throughput($j) + $cbr_throughput]

            set cross_connect           [$cbr_sink($key) GetCCC]
            set auth_connect           [$cbr_sink($key) GetAuthC]
            set sum_cross_connections [expr $sum_cross_connections + $cross_connect]
            set sum_auth_connections [expr $sum_auth_connections + $auth_connect]
        }
        puts "Mean Throughput for sink $j: [expr ($sum_cbr_throughput($j)/($opt(nn)))]"
    }

    puts "Node Stats"
    for {set i 0} {$i < $opt(nn)} {incr i}  {
        set cbr_sent_pkts        [$cbr($i) getsentpkts]
        set energy_consumed_tx [$phy($i) getConsumedEnergyTx]
        set energy_consumed_rx [$phy($i) getConsumedEnergyRx]
        set cbr_rtt             [$cbr($i) getrtt]
        set cbr_rttstd          [$cbr($i) getrttstd]
        set cbr_per             [$cbr($i) getper]
        set average_per [expr $average_per + $cbr_per]
        set sum_cbr_sent_pkts  [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
        set sum_consumed_energy_tx  [expr $sum_consumed_energy_tx + $energy_consumed_tx]
        set sum_consumed_energy_rx  [expr $sum_consumed_energy_rx + $energy_consumed_rx]
        puts "node($i) per:        $cbr_per"
        puts "node($i) rtt:        $cbr_rtt"
        puts "node($i) rtt std:    $cbr_rttstd"
        puts "---------------------------------------"
    }

    # for {set i 0} {$i < $opt(nn)} {incr i}  {
    #     set key "1, ${i}"
    #     set cbr_throughput           [$cbr_sink($key) getthr]
    #     #set cbr2_throughput           [$cbr_sink2($i) getthr]
    #     set cbr_1_thr           [$cbr($i) getthr]
    #     set cbr_sent_pkts        [$cbr($i) getsentpkts]
    #     set cbr_rcv_pkts           [$cbr_sink($key) getrecvpkts]
        
    #     puts "cbr_sink($key) throughput                    : $cbr_throughput"
    #     #puts "cbr_sink2($i) throughput                    : $cbr2_throughput"
    #     puts "cbr($i) throughput                    : $cbr_1_thr"

    #     set sum_cbr_throughput [expr $sum_cbr_throughput + $cbr_throughput]
    #     set sum_cbr_sent_pkts  [expr $sum_cbr_sent_pkts + $cbr_sent_pkts]
    #     set sum_cbr_rcv_pkts   [expr $sum_cbr_rcv_pkts + $cbr_rcv_pkts]
    # }
        
    set ipheadersize        [$ipif(0) getipheadersize]
    set udpheadersize       [$udp(0) getudpheadersize]
    set cbrheadersize       [$cbr(0) getcbrheadersize]
    
    puts "Sent Packets                        : $sum_cbr_sent_pkts"
    #puts "Received Packets                    : $sum_cbr_rcv_pkts"
    puts "Received Packets Node               : $sum_cbr_1_rcv_pkts"
    #puts "Packet Delivery Ratio               : [expr $sum_cbr_rcv_pkts / $sum_cbr_sent_pkts * 100]"
    puts "Mean Energy Consumed TX in W        : [expr $sum_consumed_energy_tx / $opt(nn) / $opt(txduration) ]"
    puts "Energy Consumed TX in W             : [expr $sum_consumed_energy_tx ]"
    puts "Mean Energy Consumed RX in W        : [expr $sum_consumed_energy_rx / $opt(nn) / $opt(txduration) ]"
    puts "Energy Consumed RX in W             : [expr $sum_consumed_energy_rx ]"
    puts "Number of cross cluster connections : $sum_cross_connections"
    puts "Number of authentication requests   : $sum_auth_connections"
    puts "Overall consumption                 : [expr $sum_consumed_energy_rx + $sum_consumed_energy_tx]"
    puts "Average PER                         : [expr $average_per / $opt(nn)]"
    # puts "IP Pkt Header Size                  : $ipheadersize"
    # puts "UDP Header Size                     : $udpheadersize"
    # puts "CBR Header Size                     : $cbrheadersize"
  
    $ns flush-trace
    close $opt(tracefile)
}

###################
# start simulation
###################
$ns at [expr $opt(stoptime)]  "finish; $ns halt" 
$ns run
