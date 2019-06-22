//
//  ZetaFormatHelpers.cpp
//  ZetaWatch
//
//  Created by cbreak on 19.06.22.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#include "ZetaFormatHelpers.hpp"

MetricPrefix const metricPrefixes[] = {
	{ 1000000000000000000, "E" },
	{    1000000000000000, "P" },
	{       1000000000000, "T" },
	{	       1000000000, "G" },
	{             1000000, "M" },
	{                1000, "k" },
};

size_t const metricPrefixCount = std::extent<decltype(metricPrefixes)>::value;
