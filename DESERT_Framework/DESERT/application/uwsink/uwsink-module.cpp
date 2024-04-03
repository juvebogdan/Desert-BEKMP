//
// Copyright (c) 2017 Regents of the SIGNET lab, University of Padova.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Neither the name of the University of Padova (SIGNET lab) nor the
//    names of its contributors may be used to endorse or promote products
//    derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

/**
 * @file   uwcbr-module.cc
 * @author Giovanni Toso
 * @version 1.1.0
 *
 * \brief Provides the <i>UWCBR</i> class implementation.
 *
 * Provides the <i>UWCBR</i> class implementation.
 */

#include "uwsink-module.h"

#include <iostream>
#include <rng.h>
#include <stdint.h>
#include <fstream>
#include <cstdlib>

#include <sstream> // Include for string stream operations
#include <string>
#include <iomanip> // For std::setprecision
#include <hiredis/hiredis.h>


extern packet_t PT_UWCBR;

int hdr_uwcbr::offset_; /**< Offset used to access in <i>hdr_uwcbr</i> packets
						   header. */

/**
 * Adds the header for <i>hdr_uwcbr</i> packets in ns2.
 */
static class UwCbrPktClass : public PacketHeaderClass
{
public:
	UwCbrPktClass()
		: PacketHeaderClass("PacketHeader/UWCBR", sizeof(hdr_uwcbr))
	{
		this->bind();
		bind_offset(&hdr_uwcbr::offset_);
	}
} class_uwcbr_pkt;

/**
 * Adds the module for UwSinkModuleClass in ns2.
 */
static class UwSinkModuleClass : public TclClass
{
public:
	UwSinkModuleClass()
		: TclClass("Module/UW/SINK")
	{
	}

	TclObject *
	create(int, const char *const *)
	{
		return (new UwSinkModule());
	}
} class_module_uwsink;

void
UwSendTimer::expire(Event *e)
{
	module->transmit();
}

int UwSinkModule::uidcnt_ = 0;

UwSinkModule::UwSinkModule()
	: dstPort_(0)
	, dstAddr_(0)
	, priority_(0)
	, PoissonTraffic_(0)
	, debug_(0)
	, Sinkid(0)
	, keyExpiry(0)
	, reAuthExpiry(100)
	, authResponseSize(48)
	, drop_out_of_order_(0)
	, traffic_type_(0)
	, sendTmr_(this)
	, txsn(1)
	, hrsn(0)
	, pkts_recv(0)
	, pkts_ooseq(0)
	, pkts_lost(0)
	, pkts_invalid(0)
	, pkts_last_reset(0)
	, rftt(-1)
	, crossClusterConnections(0)
	, authenticationRequests(0)
	, srtt(0)
	, sftt(0)
	, lrtime(0)
	, sthr(0)
	, period_(0)
	, pktSize_(0)
	, sumrtt(0)
	, sumrtt2(0)
	, rttsamples(0)
	, log_suffix("")
	, sumftt(0)
	, sumftt2(0)
	, fttsamples(0)
	, sumbytes(0)
	, sumdt(0)
	, esn(0)
	, tracefile_enabler_(0)
	, cnt(0)
{ // binding to TCL variables
	bind("period_", &period_);
	bind("destPort_", (int *) &dstPort_);
	bind("destAddr_", (int *) &dstAddr_);
	bind("packetSize_", &pktSize_);
	bind("PoissonTraffic_", &PoissonTraffic_);
	bind("debug_", &debug_);
	bind("Sinkid", &Sinkid);
	bind("keyExpiry", &keyExpiry);
	bind("reAuthExpiry", &reAuthExpiry);
	bind("authResponseSize", &authResponseSize);
	bind("drop_out_of_order_", &drop_out_of_order_);
	bind("traffic_type_", (uint *) &traffic_type_);
	bind("tracefile_enabler_", (int *) &tracefile_enabler_);
	sn_check = new bool[USHRT_MAX];
	for (int i = 0; i < USHRT_MAX; i++) {
		sn_check[i] = false;
	}
	c = redisConnect("127.0.0.1", 6379);
	if (c == nullptr || c->err) {
		if (c) {
			std::cerr << "Connection error: " << c->errstr << std::endl;
			// It's important to free the context if there's an error
			redisFree(c); 
		} else {
			std::cerr << "Connection error: can't allocate redis context" << std::endl;
		}
		throw std::runtime_error("Failed to connect to Redis");
	}
}


UwSinkModule::~UwSinkModule()
{
	cout << "sdpaosdisaopdisp" << endl;
	if (c != nullptr) {
		redisFree(c);
		c = nullptr;
	}
}

int
UwSinkModule::command(int argc, const char *const *argv)
{
	Tcl &tcl = Tcl::instance();
	if (argc == 2) {
		if (strcasecmp(argv[1], "start") == 0) {
			start();
			return TCL_OK;
		} else if (strcasecmp(argv[1], "stop") == 0) {
			stop();
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getrtt") == 0) {
			tcl.resultf("%f", GetRTT());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getftt") == 0) {
			tcl.resultf("%f", GetFTT());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "gettxtime") == 0) {
			tcl.resultf("%f", GetTxTime());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getper") == 0) {
			tcl.resultf("%f", GetPER());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getthr") == 0) {
			tcl.resultf("%f", GetTHR());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getccc") == 0) {
			tcl.resultf("%d", GetCCC());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getauthc") == 0) {
			tcl.resultf("%d", GetAuthC());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getcbrheadersize") == 0) {
			tcl.resultf("%d", this->getCbrHeaderSize());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getrttstd") == 0) {
			tcl.resultf("%f", GetRTTstd());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getfttstd") == 0) {
			tcl.resultf("%f", GetFTTstd());
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getsentpkts") == 0) {
			tcl.resultf("%d", txsn - 1);
			return TCL_OK;
		} else if (strcasecmp(argv[1], "getrecvpkts") == 0) {
			tcl.resultf("%d", pkts_recv);
			return TCL_OK;
		} else if (strcasecmp(argv[1], "setprioritylow") == 0) {
			priority_ = 0;
			return TCL_OK;
		} else if (strcasecmp(argv[1], "setpriorityhigh") == 0) {
			priority_ = 1;
			return TCL_OK;
		} else if (strcasecmp(argv[1], "sendPkt") == 0) {
			this->sendPkt();
			return TCL_OK;
		} else if (strcasecmp(argv[1], "sendPktLowPriority") == 0) {
			this->sendPktLowPriority();
			return TCL_OK;
		} else if (strcasecmp(argv[1], "sendPktHighPriority") == 0) {
			this->sendPktHighPriority();
			return TCL_OK;
		} else if (strcasecmp(argv[1], "resetStats") == 0) {
			resetStats();
			fprintf(stderr,
					"CbrModule::command() resetStats %s, pkts_last_reset=%d, "
					"hrsn=%d, txsn=%d\n",
					tag_,
					pkts_last_reset,
					hrsn,
					txsn);
			return TCL_OK;
		} else if (strcasecmp(argv[1], "printidspkts") == 0) {
			this->printIdsPkts();
			return TCL_OK;
		}
	} else if (argc == 3) {
		if (strcasecmp(argv[1], "setLogSuffix") == 0){
			string tmp_ = (char *) argv[2];
			log_suffix = std::string(tmp_);
			tracefilename = "tracefile" + log_suffix + ".txt";
			if (tracefile_enabler_) {
				tracefile.open(tracefilename.c_str() , std::ios_base::out | std::ios_base::app);
			}
		return TCL_OK;	
		}
	} else if (argc == 4) {
		if (strcasecmp(argv[1], "setLogSuffix") == 0){
			string tmp_ = (char *) argv[2];
			int precision = std::atoi(argv[3]);
			log_suffix = std::string(tmp_);
			tracefilename = "tracefile" + log_suffix + ".txt";
			if (tracefile_enabler_) {
				tracefile.open(tracefilename.c_str() , std::ios_base::out | std::ios_base::app);
				tracefile.precision(precision);
			}

		return TCL_OK;	
		}
	}
	
	return Module::command(argc, argv);
}

int
UwSinkModule::crLayCommand(ClMessage *m)
{
	switch (m->type()) {
		default:
			return Module::crLayCommand(m);
	}
}

void
UwSinkModule::initPkt(Packet *p)
{
	hdr_cmn *ch = hdr_cmn::access(p);
	ch->uid() = uidcnt_++;
	ch->ptype() = PT_UWCBR;
	ch->size() = pktSize_;

	hdr_uwip *uwiph = hdr_uwip::access(p);
	uwiph->daddr() = dstAddr_;

	hdr_uwudp *uwudp = hdr_uwudp::access(p);
	uwudp->dport() = dstPort_;

	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	uwcbrh->sn() = txsn++;
	uwcbrh->priority() = priority_;
	uwcbrh->traffic_type() = traffic_type_;
	ch->timestamp() = Scheduler::instance().clock();

	if (rftt >= 0) {
		uwcbrh->rftt() = rftt;
		uwcbrh->rftt_valid() = true;
	} else {
		uwcbrh->rftt_valid() = false;
	}
}

void
UwSinkModule::initPktKey(Packet *p, int packetSize, uint traffic_type, nsaddr_t destAddr)
{
	hdr_cmn *ch = hdr_cmn::access(p);
	ch->uid() = uidcnt_++;
	ch->ptype() = PT_UWCBR;
	ch->size() = packetSize;

	hdr_uwip *uwiph = hdr_uwip::access(p);
	uwiph->daddr() = destAddr;

	hdr_uwudp *uwudp = hdr_uwudp::access(p);
	uwudp->dport() = dstPort_;

	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	uwcbrh->sn() = txsn++;
	uwcbrh->priority() = priority_;
	uwcbrh->traffic_type() = traffic_type;
	ch->timestamp() = Scheduler::instance().clock();

	if (rftt >= 0) {
		uwcbrh->rftt() = rftt;
		uwcbrh->rftt_valid() = true;
	} else {
		uwcbrh->rftt_valid() = false;
	}
}

void
UwSinkModule::start()
{
	sendTmr_.resched(getTimeBeforeNextPkt());
}

void
UwSinkModule::sendPkt()
{
	double delay = 0;
	Packet *p = Packet::alloc();
	this->initPkt(p);
	hdr_cmn *ch = hdr_cmn::access(p);
	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	if (debug_ > 10)
		printf("CbrModule changed(%d)::sendPkt, send a pkt (%d) with sn: %d\n",
				getId(),
				ch->uid(),
				uwcbrh->sn());
	sendDown(p, delay);
}

void
UwSinkModule::sendPktKey(double delay, int packetSize, uint traffic_type, nsaddr_t destAddr)
{
	Packet *p = Packet::alloc();
	this->initPktKey(p, packetSize, traffic_type, destAddr);
	hdr_cmn *ch = hdr_cmn::access(p);
	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	if (debug_ > 10)
		printf("CbrModule changed(%d)::sendPkt, send a pkt (%d) with sn: %d\n",
				getId(),
				ch->uid(),
				uwcbrh->sn());
	sendDown(p, delay);
}

void
UwSinkModule::sendPktLowPriority()
{
	double delay = 0;
	Packet *p = Packet::alloc();
	this->initPkt(p);
	hdr_cmn *ch = hdr_cmn::access(p);
	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	uwcbrh->priority() = 0;
	if (debug_ > 10)
		printf("CbrModule(%d)::sendPkt, send a pkt (%d) with sn: %d\n",
				getId(),
				ch->uid(),
				uwcbrh->sn());
	sendDown(p, delay);
}

void
UwSinkModule::sendPktHighPriority()
{
	double delay = 0;
	Packet *p = Packet::alloc();
	this->initPkt(p);
	hdr_cmn *ch = hdr_cmn::access(p);
	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	uwcbrh->priority() = 1;
	if (debug_ > 10)
		printf("CbrModule(%d)::sendPkt, send a pkt (%d) with sn: %d\n",
				getId(),
				ch->uid(),
				uwcbrh->sn());
	sendDown(p, delay);
}

void
UwSinkModule::transmit()
{
	sendPkt();
	sendTmr_.resched(getTimeBeforeNextPkt()); // schedule next transmission
}

void
UwSinkModule::stop()
{
	sendTmr_.force_cancel();
}

void
UwSinkModule::recv(Packet *p, Handler *h)
{
	//    hdr_cmn* ch = hdr_cmn::access(p);
	recv(p);
}

bool hasWritten = false; // Static flag to ensure we write only once

void
UwSinkModule::recv(Packet *p)
{
	hdr_cmn *ch = hdr_cmn::access(p);
	hdr_uwip *uwiph = hdr_uwip::access(p);

	if (debug_ > 10)
		printf("CbrModule(%d)::recv(Packet*p,Handler*) pktId %d\n",
				getId(),
				ch->uid());

	if (ch->ptype() != PT_UWCBR) {
		drop(p, 1, UWCBR_DROP_REASON_UNKNOWN_TYPE);
		incrPktInvalid();
		return;
	}

	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	esn = hrsn + 1; // expected sn

	if (!drop_out_of_order_) {
		if (sn_check[uwcbrh->sn() &
					0x00ffffff]) { // Packet already processed: drop it
			incrPktInvalid();
			drop(p, 1, UWCBR_DROP_REASON_DUPLICATED_PACKET);
			return;
		}
	}

	sn_check[uwcbrh->sn() & 0x00ffffff] = true;

	if (drop_out_of_order_) {
		if (uwcbrh->sn() <
				esn) { // packet is out of sequence and is to be discarded
			incrPktOoseq();
			if (debug_ > 1) {
				printf("CbrModule::recv() Pkt out of sequence! "
					   "cbrh->sn=%d\thrsn=%d\tesn=%d\n",
						uwcbrh->sn(),
						hrsn,
						esn);
			}
			drop(p, 1, UWCBR_DROP_REASON_OUT_OF_SEQUENCE);
			return;
		}
	}

	rftt = Scheduler::instance().clock() - ch->timestamp();

	if (uwcbrh->rftt_valid()) {
		double rtt = rftt + uwcbrh->rftt();
		updateRTT(rtt);
	}

	updateFTT(rftt);

	/* a new packet has been received */
	incrPktRecv();

	hrsn = uwcbrh->sn();
	if (drop_out_of_order_) {
		if (uwcbrh->sn() > esn) { // packet losses are observed
			incrPktLost(uwcbrh->sn() - (esn));
		}
	}

	double dt = Scheduler::instance().clock() - lrtime;

	updateThroughput(ch->size(), dt); 

	int sourceAddress = uwiph->saddr();
	int receivedTrafficType = uwcbrh->traffic_type();
	int sequenceNumber = uwcbrh->sn();

	//redisContext* c = redisConnect("127.0.0.1", 6379);
	if (!c || c->err) {
		if (c) std::cerr << "Connection error: " << c->errstr << std::endl;
		else std::cerr << "Cannot allocate redis context" << std::endl;
		return; // or handle error appropriately
	}

	std::string packet_identifier = std::to_string(sourceAddress) + ":" + std::to_string(sequenceNumber);
	std::string firstReceiverKey = "packet:first_receiver:" + packet_identifier;

	// Attempt to mark this sink as the first receiver for the packet
	auto firstReceiverReply = (redisReply*)redisCommand(c, "SETNX %s %d", firstReceiverKey.c_str(), Sinkid);
	bool isFirstReceiver = firstReceiverReply && firstReceiverReply->type == REDIS_REPLY_INTEGER && firstReceiverReply->integer == 1;
	if (firstReceiverReply) freeReplyObject(firstReceiverReply);
	std::string authKey = "node:auth_status:" + std::to_string(sourceAddress);
	std::string reAuthKey = "node:re_auth_status:" + std::to_string(sourceAddress) + ":" + std::to_string(Sinkid);

	if (isFirstReceiver) {
		if (tracefile_enabler_) {
			printReceivedPacket(p);
		}
		if (receivedTrafficType == 5) {
			authenticationRequests++;
			// Authentication request
			double authExpirationTime = Scheduler::instance().clock() + keyExpiry;
			redisCommand(c, "HMSET %s expiration %f sinkId %d", authKey.c_str(), authExpirationTime, Sinkid);
			sendPktKey(0.0, authResponseSize, 5, static_cast<nsaddr_t>(sourceAddress));
		} else if (receivedTrafficType == 10 || receivedTrafficType == 8) {
			double currentTime = Scheduler::instance().clock();
			auto authReply = (redisReply*)redisCommand(c, "HGETALL %s", authKey.c_str());
			if (authReply && authReply->type == REDIS_REPLY_ARRAY) {
				if (authReply->elements != 0) {
					double authExpirationTime = 0;
					int registeredSinkId = -1;
					// The loop won't execute if authReply->elements is 0, i.e., the key doesn't exist or has no fields
					for (size_t i = 0; i < authReply->elements; i += 2) {
						std::string field = authReply->element[i]->str;
						if (field == "expiration") {
							authExpirationTime = atof(authReply->element[i + 1]->str);
						}
						else if (field == "sinkId") {
							registeredSinkId = atoi(authReply->element[i + 1]->str);
						}
					}
					if (Sinkid != registeredSinkId) {
						crossClusterConnections++;
					}
					// If authExpirationTime remains 0, it means either the key didn't exist or it had no 'expiration' field
					if (currentTime > authExpirationTime || authExpirationTime == 0) {
						// Authentication expired or not found, respond with traffic type 6
						sendPktKey(0.0, 10, 6, static_cast<nsaddr_t>(sourceAddress));
					}
					else {
						if (Sinkid != registeredSinkId) {
							if (receivedTrafficType == 8) {
								double reAuthExpirationTime = Scheduler::instance().clock() + reAuthExpiry;
								redisCommand(c, "HMSET %s expiration %f sinkId %d", reAuthKey.c_str(), reAuthExpirationTime, Sinkid);
								sendPktKey(0.0, 8, 8, static_cast<nsaddr_t>(sourceAddress));									
							}
							else {
								//paket je stigao i autentifikovan je nod, medjutim sada prelazi na drugi sink. potrebno je provjeriti je li vec odradjen reauth.
								//ako je reauth odradjen i paket je 10 onda nista.
								auto reAuthReply = (redisReply*)redisCommand(c, "HGETALL %s", reAuthKey.c_str());
								if (reAuthReply && reAuthReply->type == REDIS_REPLY_ARRAY) {
									if (reAuthReply->elements != 0) {
										double reAuthExpirationTime = 0;
										// The loop won't execute if authReply->elements is 0, i.e., the key doesn't exist or has no fields
										for (size_t i = 0; i < reAuthReply->elements; i += 2) {
											std::string field = reAuthReply->element[i]->str;
											if (field == "expiration") {
												reAuthExpirationTime = atof(reAuthReply->element[i + 1]->str);
											}
										}
										if (currentTime > reAuthExpirationTime || reAuthExpirationTime == 0) {
											// Authentication expired or not found, respond with traffic type 7
											sendPktKey(0.0, 10, 7, static_cast<nsaddr_t>(sourceAddress));
										}
									}
									else {
										sendPktKey(0.0, 10, 7, static_cast<nsaddr_t>(sourceAddress));
									}
								}
								if (reAuthReply) freeReplyObject(reAuthReply);
							}
						}
					}
				}
				else {
					sendPktKey(0.0, 10, 6, static_cast<nsaddr_t>(sourceAddress));
				}
			}
			if (authReply) freeReplyObject(authReply);
		}
	}

	lrtime = Scheduler::instance().clock();

	Packet::free(p);

	if (drop_out_of_order_) {
		if (pkts_lost + pkts_recv + pkts_last_reset != hrsn) {
			fprintf(stderr,
					"ERROR CbrModule::recv() pkts_lost=%d  pkts_recv=%d  "
					"hrsn=%d\n",
					pkts_lost,
					pkts_recv,
					hrsn);
		}
	}
}

double
UwSinkModule::GetRTT() const
{
	return (rttsamples > 0) ? sumrtt / rttsamples : 0;
}

double
UwSinkModule::GetFTT() const
{
	return (fttsamples > 0) ? sumftt / fttsamples : 0;
}

double
UwSinkModule::GetTxTime() const
{
	return (fttsamples > 0) ? sumtxtimes / fttsamples : 0;
}

double
UwSinkModule::GetRTTstd() const
{
	if (rttsamples > 1) {
		double var =
				(sumrtt2 - (sumrtt * sumrtt / rttsamples)) / (rttsamples - 1);
		return (sqrt(var));
	} else
		return 0;
}

double
UwSinkModule::GetFTTstd() const
{
	if (fttsamples > 1) {
		double var = 0;
		var = (sumftt2 - (sumftt * sumftt / fttsamples)) / (fttsamples - 1);
		if (var > 0)
			return (sqrt(var));
		else
			return 0;
	} else {
		return 0;
	}
}

double
UwSinkModule::GetPER() const
{
	if ((pkts_recv + pkts_lost) > 0) {
		return ((double) pkts_lost / (double) (pkts_recv + pkts_lost));
	} else {
		return 0;
	}
}

double
UwSinkModule::GetTHR() const
{
	return ((sumdt != 0) ? sumbytes * 8 / sumdt : 0);
}

int
UwSinkModule::GetCCC() const
{
	return crossClusterConnections;
}

int
UwSinkModule::GetAuthC() const
{
	return authenticationRequests;
}

void
UwSinkModule::updateRTT(const double &rtt)
{
	sumrtt += rtt;
	sumrtt2 += rtt * rtt;
	rttsamples++;
}

void
UwSinkModule::updateFTT(const double &ftt)
{
	sumftt += ftt;
	sumftt2 += ftt * ftt;
	fttsamples++;
}

void
UwSinkModule::updateThroughput(const int &bytes, const double &dt)
{
	sumbytes += bytes;
	sumdt += dt;

	if (debug_ > 1) {
		cerr << "bytes=" << bytes << "  dt=" << dt << endl;
	}
}

void
UwSinkModule::incrPktLost(const int &npkts)
{
	pkts_lost += npkts;
}

void
UwSinkModule::incrPktRecv()
{
	pkts_recv++;
}

void
UwSinkModule::incrPktOoseq()
{
	pkts_ooseq++;
}

void
UwSinkModule::incrPktInvalid()
{
	pkts_invalid++;
}

void
UwSinkModule::resetStats()
{
	pkts_last_reset += pkts_lost + pkts_recv;
	pkts_recv = 0;
	pkts_ooseq = 0;
	pkts_lost = 0;
	srtt = 0;
	sftt = 0;
	sthr = 0;
	rftt = -1;
	sumrtt = 0;
	sumrtt2 = 0;
	rttsamples = 0;
	sumftt = 0;
	sumftt2 = 0;
	fttsamples = 0;
	sumbytes = 0;
	sumdt = 0;
}

double
UwSinkModule::getTimeBeforeNextPkt()
{
	if (period_ < 0) {
		fprintf(stderr, "%s : Error : period <= 0", __PRETTY_FUNCTION__);
		exit(1);
	}
	if (PoissonTraffic_) {
		double u = RNG::defaultrng()->uniform_double();
		double lambda = 1 / period_;
		return (-log(u) / lambda);
	} else {
		// CBR
		return period_;
	}
}

void 
UwSinkModule::printReceivedPacket(Packet *p)
{
	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);
	hdr_cmn *ch = hdr_cmn::access(p);
	hdr_uwip *uwiph = hdr_uwip::access(p);
	if (tracefile_enabler_) {
		tracefile << NOW << " " << ch->timestamp() << " " << uwcbrh->sn() << " " 
				<< (int) uwiph->saddr() << " " << (int) uwiph->daddr() << " " << uwcbrh->traffic_type() << " " << ch->size() <<"\n";
		tracefile.flush();
	}
}
