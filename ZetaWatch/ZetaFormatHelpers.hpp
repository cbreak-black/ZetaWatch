//
//  ZetaFormatHelpers.hpp
//  ZetaWatch
//
//  Created by cbreak on 19.06.22.
//  Copyright © 2019 the-color-black.net. All rights reserved.
//

#ifndef ZetaFormatHelpers_hpp
#define ZetaFormatHelpers_hpp

#include <sstream>
#include <string>
#include <iomanip>

struct MetricPrefix
{
	uint64_t factor;
	char const * prefix;
};

extern MetricPrefix const metricPrefixes[];
extern size_t const metricPrefixCount;

template<typename T>
std::string formatPrefixedValue(T size)
{
	for (size_t p = 0; p < metricPrefixCount; ++p)
	{
		if (size > metricPrefixes[p].factor)
		{
			double scaledSize = size / double(metricPrefixes[p].factor);
			std::stringstream ss;
			ss << std::setprecision(2) << std::fixed << scaledSize << " " << metricPrefixes[p].prefix;
			return ss.str();
		}
	}
	return std::to_string(size) + " ";
}

template<typename T>
std::string formatBytes(T bytes)
{
	return formatPrefixedValue(bytes) + "B";
}

inline std::string formatRate(uint64_t bytes, std::chrono::seconds const & time)
{
	return formatBytes(bytes / time.count()) + "/s";
}

template<typename T> T toFormatable(T t)
{
	return t;
}

inline char const * toFormatable(std::string const & str)
{
	return str.c_str();
}

inline std::string trim(std::string const & s)
{
	size_t first = s.find_first_not_of(' ');
	size_t last = s.find_last_not_of(' ');
	if (first != std::string::npos)
		return s.substr(first, last - first + 1);
	return s;
}

#endif /* ZetaMenuHelpers_h */
