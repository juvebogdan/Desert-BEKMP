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
 * @file   uwsink-tracer.cc
 * @author Giovanni Toso
 * @version 1.1.0
 *
 * \brief Provides a tracer class for <i>UWCBR</i> packets.
 *
 * Provides a tracer class for <i>UWCBR</i> packets.
 */

#include "uwsink-module.h"

/**
 * Class that defines a tracer for <i>hdr_uwcbr</i> packets.
 */
class UWSinkTracer : public Tracer
{
public:
	UWSinkTracer();

protected:
	void format(Packet *p, SAP *sap);
};

UWSinkTracer::UWSinkTracer()
	: Tracer(4)
{
}

void
UWSinkTracer::format(Packet *p, SAP *sap)
{
	hdr_cmn *ch = hdr_cmn::access(p);

	if (ch->ptype() != PT_UWCBR)
		return;

	hdr_uwcbr *uwcbrh = HDR_UWCBR(p);

	if (uwcbrh->rftt_valid_) {
		writeTrace(sap, " SN=%d", uwcbrh->sn());
	} else {
		writeTrace(sap, " SN=%d", uwcbrh->sn());
	}
}

extern "C" int
Uwsinktracer_Init()
{
	SAP::addTracer(new UWSinkTracer);
	return 0;
}

extern "C" int
Cyguwsinktracer_Init()
{
	Uwsinktracer_Init();
	return 0;
}
