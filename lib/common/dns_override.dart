/// 常见的公共 DNS，用于过滤订阅中的公共 DNS
const commonDnsList = [
  // IP（国内）
  '223.5.5.5',
  '223.6.6.6',
  '119.29.29.29',
  '1.12.12.12',
  '120.53.53.53',
  '114.114.114.114',
  '180.76.76.76',
  '1.2.4.8',
  '116.116.116.116',
  '101.226.4.6',
  '123.125.81.6',
  '180.184.1.1',
  '180.184.2.2',

  // IP（国外）
  '1.1.1.1',
  '1.0.0.1',
  '8.8.8.8',
  '8.8.4.4',
  '9.9.9.9',
  '149.112.112.112',
  '208.67.222.222',
  '208.67.220.220',
  '94.140.14.14',
  '94.140.15.15',
  '76.76.2.0',
  '76.76.10.0',
  '185.228.168.9',
  '185.228.169.9',
  '77.88.8.8',
  '77.88.8.1',
  '156.154.70.1',
  '156.154.71.1',

  // 关键词（国内）
  'alidns',
  'doh.pub',
  'dot.pub',
  'dns.pub',
  'dnspod',
  'dns.baidu',

  // 关键词（国外）
  'dns.google',
  'cloudflare',
  'quad9',
  'opendns',
  'nextdns',
  'adguard',

  // 系统
  'system',
];

/// hosts 匹配优先级：精确 > +. > . > *（同级按出现顺序）
int hostSpecificity(String pattern) {
  if (pattern.startsWith('+.')) return 2;
  if (pattern.startsWith('.')) return 1;
  if (pattern.contains('*')) return 0;
  return 3;
}

/// 判断域名规则（精确/通配）是否匹配节点域名集合，忽略大小写
bool matchDomainPattern(String pattern, Iterable<String> domains) {
  pattern = pattern.toLowerCase();

  // 精确匹配
  if (!pattern.contains('*') && !pattern.startsWith('+.') && !pattern.startsWith('.')) {
    return domains.any((d) => d.toLowerCase() == pattern);
  }

  final domainList = domains.map((d) => d.toLowerCase()).toList();

  // +.example.com
  if (pattern.startsWith('+.')) {
    final suffix = pattern.substring(2);
    return domainList.any((domain) => domain == suffix || domain.endsWith('.$suffix'));
  }

  // .example.com
  if (pattern.startsWith('.')) {
    final suffix = pattern.substring(1);
    return domainList.any((domain) => domain != suffix && domain.endsWith('.$suffix'));
  }

  // *.example.com、example.*.com 等
  final patternParts = pattern.split('.');
  return domainList.any((domain) {
    final domainParts = domain.split('.');
    return patternParts.length == domainParts.length &&
        patternParts.indexed.every(
          (entry) => entry.$2 == '*' || entry.$2 == domainParts[entry.$1],
        );
  });
}

/// 剥离 DNS 地址的 # 策略组后缀；# 后为 direct（忽略大小写，可带 & 参数）时整条保留
String stripDnsSuffix(String dns) {
  final hashIndex = dns.indexOf('#');
  if (hashIndex == -1) return dns;
  final suffix = dns.substring(hashIndex + 1).toLowerCase().trim();
  if (suffix == 'direct' || suffix.startsWith('direct&')) return dns;
  return dns.substring(0, hashIndex);
}

/// 根据订阅 hosts 映射改写节点 server（链式解析 + 回环防御 + 缓存）
List<dynamic> applyHostsToProxies(List<dynamic> proxies, Map<String, dynamic>? hosts) {
  if (hosts == null || hosts.isEmpty) return proxies;

  // 全部有效条目按匹配优先级排序（链式解析需保留中继条目，故不按节点域名预过滤）
  final hostEntries = hosts.entries
      .where((entry) =>
          (entry.value is String && (entry.value as String).isNotEmpty) ||
          (entry.value is List && (entry.value as List).isNotEmpty))
      .toList()
    ..sort((a, b) => hostSpecificity(b.key) - hostSpecificity(a.key));
  if (hostEntries.isEmpty) return proxies;

  // 取映射目标（数组取首个非空字符串），无有效目标时返回 null
  String? targetOf(dynamic value) {
    if (value is List) {
      for (final item in value) {
        if (item is String && item.isNotEmpty) return item;
      }
      return null;
    }
    return value is String && value.isNotEmpty ? value : null;
  }

  // 解析结果缓存：相同节点域名只解析一次，后续直接复用
  final resolveCache = <String, String>{};

  // 解析单个节点域名：沿链式映射逐级改写至最终目标，无匹配时原样返回
  String resolve(String server) {
    final cached = resolveCache[server];
    if (cached != null) return cached;

    final seen = <String>{};
    var current = server.toLowerCase();
    var result = server;
    while (seen.add(current)) {
      MapEntry<String, dynamic>? entry;
      for (final e in hostEntries) {
        if (matchDomainPattern(e.key, [current])) {
          entry = e;
          break;
        }
      }
      final target = entry == null ? null : targetOf(entry.value);
      if (target == null) break;
      result = target;
      current = target.toLowerCase();
    }
    resolveCache[server] = result;
    return result;
  }

  return proxies.map((proxy) {
    if (proxy is! Map) return proxy;
    final server = proxy['server'];
    if (server is! String) return proxy;
    final resolved = resolve(server);
    return resolved == server ? proxy : {...proxy, 'server': resolved};
  }).toList();
}

/// 将订阅中的私有 DNS、节点域名解析策略与 hosts 映射合并进覆写后的 DNS 配置。
/// 需在 DNS 覆写（rawConfig['dns'] 被覆盖）之前快照 [originalDns] 与 [originalHosts]。
void applyDnsNodeOverride(
  Map<String, dynamic> rawConfig, {
  Map<String, dynamic>? originalDns,
  Map<String, dynamic>? originalHosts,
}) {
  originalDns ??= {};

  // 仅当原配置 proxy-server-nameserver 有且仅有一个 DNS，且该 DNS 包含非空的 listen 时，
  // 才根据订阅 hosts 改写节点 server，否则跳过改写
  final proxyServerNameservers =
      (originalDns['proxy-server-nameserver'] as List?)?.cast<String>() ?? [];
  final listenValue = originalDns['listen'];
  final shouldRewriteByHosts = proxyServerNameservers.length == 1 &&
      listenValue is String &&
      listenValue.isNotEmpty &&
      proxyServerNameservers.any(
        (dns) => dns.toLowerCase().contains(listenValue.toLowerCase()),
      );

  final proxies = (rawConfig['proxies'] as List?) ?? const [];

  // 根据订阅 hosts 改写节点 server 为映射后的地址（域名或 IP），并回写
  final mappedProxies =
      shouldRewriteByHosts ? applyHostsToProxies(proxies, originalHosts) : proxies;
  if (!identical(mappedProxies, proxies)) {
    rawConfig['proxies'] = mappedProxies;
  }

  // 节点域名集合：合并改写前/后的 server（未触发 hosts 改写时两者一致）
  final proxyDomains = <String>{};
  void collectServers(List<dynamic> list) {
    for (final proxy in list) {
      if (proxy is Map) {
        final server = proxy['server'];
        if (server is String) proxyDomains.add(server.toLowerCase());
      }
    }
  }

  collectServers(proxies);
  if (shouldRewriteByHosts) {
    collectServers(mappedProxies);
  }

  // 命中 hosts 改写时，将 listen 值加入公共 DNS 列表，
  // 使其在私有 DNS 提取时被当作公共 DNS 过滤，避免 listen 地址被误留为私有 DNS
  final commonDnsSet = commonDnsList.toSet();
  if (shouldRewriteByHosts) {
    commonDnsSet.add(listenValue);
  }
  final commonDnsRegex = RegExp(
    commonDnsSet.map(RegExp.escape).join('|'),
    caseSensitive: false,
  );
  bool isCommonDns(String dns) => commonDnsRegex.hasMatch(dns);

  // 提取私有 DNS（先剥离 # 策略组后缀，再判断是否为公共 DNS）
  final privateDNS = <String>{};
  for (final dns in [...(originalDns['nameserver'] as List? ?? const []), ...proxyServerNameservers]) {
    final stripped = stripDnsSuffix(dns.toString());
    if (stripped.isNotEmpty && !isCommonDns(stripped)) {
      privateDNS.add(stripped);
    }
  }

  // 提取节点域名对应的 DNS 配置（剥离 # 策略组后缀）
  final originalPolicy = <String, dynamic>{
    ...?((originalDns['nameserver-policy'] as Map?)?.cast<String, dynamic>()),
    ...?((originalDns['proxy-server-nameserver-policy'] as Map?)?.cast<String, dynamic>()),
  };
  final proxyServerPolicy = <String, dynamic>{};
  for (final entry in originalPolicy.entries) {
    if (!matchDomainPattern(entry.key, proxyDomains)) continue;

    final value = entry.value;
    final strippedValue = value is List
        ? value.map((item) => stripDnsSuffix(item.toString())).where((item) => item.isNotEmpty).toList()
        : stripDnsSuffix(value.toString());
    if (strippedValue is List && strippedValue.isEmpty) continue;

    proxyServerPolicy[entry.key] = strippedValue;
  }

  // 遍历原配置中的 fake-ip-filter，保留与节点域名匹配的条目
  // 部分机场的节点域名需走真实 IP 解析，避免 fake-ip 导致节点无法连接
  final originalFakeIpFilter = (originalDns['fake-ip-filter'] as List?) ?? const [];
  final proxyFakeIpFilter = originalFakeIpFilter
      .where((pattern) => matchDomainPattern(pattern.toString(), proxyDomains))
      .map((pattern) => pattern.toString())
      .toList();

  final dns = (rawConfig['dns'] as Map?)?.cast<String, dynamic>();
  if (dns == null) return;

  // 写入覆写后的 DNS：私有 DNS / 节点域名 policy / fake-ip-filter 节点域名条目
  if (privateDNS.isNotEmpty) {
    dns['proxy-server-nameserver'] = privateDNS.toList();
  }
  if (proxyServerPolicy.isNotEmpty) {
    dns['proxy-server-nameserver-policy'] = proxyServerPolicy;
  }
  if (proxyFakeIpFilter.isNotEmpty) {
    final existingFilter = (dns['fake-ip-filter'] as List?) ?? const [];
    dns['fake-ip-filter'] = [...existingFilter, ...proxyFakeIpFilter];
  }
}
