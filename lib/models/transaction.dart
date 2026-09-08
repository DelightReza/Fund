class TransactionModel {
  final String id;
  final String type; // 'credit' | 'debit'
  final String? payerId;
  final String? billTypeId;
  final List<String>? splitAmong; // Clean member IDs e.g. ['aabid', 'gulam', 'raza']
  final List<String>? exemptions;
  final Map<String, double>? customSplit; // memberId -> exact share amount
  final Map<String, double>? splitPercentages; // memberId -> percentage (e.g. 50.0, 30.0, 20.0)
  final String whoOrBill;
  final String note;
  final double amount;
  final String date;
  final String? parentId;
  final double? distributionTotal;

  TransactionModel({
    required this.id,
    required this.type,
    this.payerId,
    this.billTypeId,
    List<String>? splitAmong,
    this.exemptions,
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
    required this.whoOrBill,
    required this.note,
    required this.amount,
    required this.date,
    this.parentId,
    this.distributionTotal,
  })  : splitAmong = _extractCleanMembers(splitAmong, exemptions),
        customSplit = _extractCustomSplit(amount, splitAmong, customSplit, splitPercentages, exemptions),
        splitPercentages = _extractPercentages(amount, splitAmong, customSplit, splitPercentages, exemptions);

  /// Helper to extract clean member IDs from splitAmong list (filtering out exemptions)
  static List<String>? _extractCleanMembers(List<String>? splitAmong, [List<String>? exemptions]) {
    if (splitAmong == null) return null;
    final exemptSet = exemptions?.toSet() ?? const <String>{};
    final list = splitAmong
        .map((e) => parseSplitItem(e).id)
        .where((id) => id.isNotEmpty && !exemptSet.contains(id))
        .toList();
    return list.isNotEmpty ? list : null;
  }

  /// Helper to extract percentage allocations (filtering out exemptions and 0s)
  static Map<String, double>? _extractPercentages(
    double amount,
    List<String>? splitAmong,
    Map<String, double>? existingCustomSplit,
    Map<String, double>? existingPercentages, [
    List<String>? exemptions,
  ]) {
    final exemptSet = exemptions?.toSet() ?? const <String>{};
    if (existingPercentages != null && existingPercentages.isNotEmpty) {
      final filtered = Map<String, double>.from(existingPercentages)
        ..removeWhere((k, v) => exemptSet.contains(k) || v <= 0.0);
      if (filtered.isNotEmpty) return filtered;
    }
    if (existingCustomSplit != null && existingCustomSplit.isNotEmpty && amount > 0) {
      final filteredCustom = Map<String, double>.from(existingCustomSplit)
        ..removeWhere((k, v) => exemptSet.contains(k) || v <= 0.0);
      final pcts = calculatePercentagesFromCustomSplit(
        totalAmount: amount,
        customSplit: filteredCustom,
      );
      if (pcts.isNotEmpty && !isSplitEqual(pcts)) {
        return pcts;
      }
    }
    if (splitAmong != null && splitAmong.isNotEmpty) {
      final pcts = <String, double>{};
      for (final item in splitAmong) {
        final parsed = parseSplitItem(item);
        if (parsed.id.isNotEmpty && !exemptSet.contains(parsed.id) && parsed.percentage != null) {
          if (parsed.percentage! > 0) {
            pcts[parsed.id] = parsed.percentage!;
          }
        }
      }
      if (pcts.isNotEmpty) return pcts;
    }
    return null;
  }

  /// Helper to compute exact amount custom split (filtering out exemptions and 0s)
  static Map<String, double>? _extractCustomSplit(
    double amount,
    List<String>? splitAmong,
    Map<String, double>? existingCustomSplit,
    Map<String, double>? existingPercentages, [
    List<String>? exemptions,
  ]) {
    final exemptSet = exemptions?.toSet() ?? const <String>{};
    if (existingCustomSplit != null && existingCustomSplit.isNotEmpty) {
      final filtered = Map<String, double>.from(existingCustomSplit)
        ..removeWhere((k, v) => exemptSet.contains(k) || v <= 0.0);
      if (filtered.isNotEmpty) return filtered;
    }
    if (splitAmong != null && splitAmong.isNotEmpty) {
      final map = <String, double>{};
      final pcts = <String, double>{};
      for (final item in splitAmong) {
        final parsed = parseSplitItem(item);
        if (parsed.id.isNotEmpty && !exemptSet.contains(parsed.id)) {
          if (parsed.amount != null) {
            if (parsed.amount! > 0) {
              map[parsed.id] = parsed.amount!;
            }
          } else if (parsed.percentage != null) {
            if (parsed.percentage! > 0) {
              pcts[parsed.id] = parsed.percentage!;
            }
          }
        }
      }
      if (map.isNotEmpty) return map;
      if (pcts.isNotEmpty && amount > 0) {
        final members = _extractCleanMembers(splitAmong, exemptions) ?? pcts.keys.toList();
        return calculateCustomSplitFromPercentages(
          totalAmount: amount,
          percentages: pcts,
          memberIds: members,
        );
      }
    }
    if (existingPercentages != null && existingPercentages.isNotEmpty && amount > 0) {
      final filteredPcts = Map<String, double>.from(existingPercentages)
        ..removeWhere((k, v) => exemptSet.contains(k) || v <= 0.0);
      final members = _extractCleanMembers(splitAmong, exemptions) ?? filteredPcts.keys.toList();
      if (filteredPcts.isNotEmpty && members.isNotEmpty) {
        return calculateCustomSplitFromPercentages(
          totalAmount: amount,
          percentages: filteredPcts,
          memberIds: members,
        );
      }
    }
    return null;
  }

  /// Returns true if this transaction has an unequal custom amount or percentage split
  bool get hasCustomSplit =>
      (customSplit != null && customSplit!.isNotEmpty && !isSplitEqual(customSplit!)) ||
      (splitPercentages != null && splitPercentages!.isNotEmpty && !isSplitEqual(splitPercentages!));

  /// Returns clean member IDs involved in this split (excluding exemptions and 0-allocations)
  List<String> get cleanSplitMembers {
    List<String> list = const [];
    if (splitAmong != null && splitAmong!.isNotEmpty) {
      list = splitAmong!.map((e) => parseSplitItem(e).id).where((id) => id.isNotEmpty).toList();
    } else if (customSplit != null && customSplit!.isNotEmpty) {
      list = customSplit!.keys.toList();
    } else if (splitPercentages != null && splitPercentages!.isNotEmpty) {
      list = splitPercentages!.keys.toList();
    }

    final exemptSet = exemptions?.toSet() ?? const <String>{};
    return list.where((id) {
      if (exemptSet.contains(id)) return false;
      if (customSplit != null && customSplit!.containsKey(id)) {
        if ((customSplit![id] ?? 0.0) <= 0.0) return false;
      }
      return true;
    }).toList();
  }

  /// Formatted splitAmong:
  /// - Equal split: ["aabid", "gulam", "raza"]
  /// - Equal split with exemption: ["gulam", "raza"] (when aabid is exempt)
  /// - Unequal split: ["aabid 60", "gulam 30", "raza 20"] (when total money is 110)
  /// - Unequal split with exemption: ["gulam 30", "raza 20"] (when aabid is exempt)
  List<String> get formattedSplitAmong {
    final members = cleanSplitMembers;
    if (members.isEmpty) return const [];

    if (hasCustomSplit) {
      final amounts = customSplit ??
          (splitPercentages != null && amount > 0
              ? calculateCustomSplitFromPercentages(
                  totalAmount: amount,
                  percentages: splitPercentages!,
                  memberIds: members,
                )
              : null);

      if (amounts != null && amounts.isNotEmpty) {
        final result = <String>[];
        for (final id in members) {
          if (exemptions != null && exemptions!.contains(id)) continue;
          final amt = amounts[id];
          if (amt == null || amt <= 0.0) continue;
          final amtStr = (amt % 1.0 == 0.0)
              ? amt.toInt().toString()
              : amt.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
          result.add('$id $amtStr');
        }
        return result;
      }
    }
    return members;
  }

  /// Parses an individual split item that could be:
  /// - "aabid" -> id: "aabid", amount: null, percentage: null
  /// - "aabid 60" -> id: "aabid", amount: 60.0, percentage: null
  /// - "aabid 50%" -> id: "aabid", amount: null, percentage: 50.0
  /// - "aabid: 60" -> id: "aabid", amount: 60.0, percentage: null
  /// - {"id": "aabid", "amount": 60} -> id: "aabid", amount: 60.0
  /// - {"id": "aabid", "percentage": 50} -> id: "aabid", percentage: 50.0
  /// - {"aabid": 60} -> id: "aabid", amount: 60.0
  static ({String id, double? amount, double? percentage}) parseSplitItem(dynamic item) {
    if (item == null) return (id: '', amount: null, percentage: null);
    if (item is Map) {
      if (item.containsKey('id')) {
        final id = item['id']?.toString().trim() ?? '';
        final amt = (item['amount'] as num?)?.toDouble();
        final p = (item['percent'] ?? item['percentage'] as num?)?.toDouble();
        return (id: id, amount: amt, percentage: p);
      } else if (item.isNotEmpty) {
        final id = item.keys.first.toString().trim();
        final val = (item.values.first as num?)?.toDouble();
        return (id: id, amount: val, percentage: null);
      }
    }
    final s = item.toString().trim();
    final match = RegExp(r'^([a-zA-Z0-9_\-]+)(?:[\s:]+(\d+(?:\.\d+)?)\s*(%?))?$').firstMatch(s);
    if (match != null) {
      final id = match.group(1)!;
      final numStr = match.group(2);
      final isPct = match.group(3) == '%';
      if (numStr != null) {
        final val = double.tryParse(numStr);
        if (isPct) {
          return (id: id, amount: null, percentage: val);
        } else {
          return (id: id, amount: val, percentage: null);
        }
      }
      return (id: id, amount: null, percentage: null);
    }
    return (id: s, amount: null, percentage: null);
  }

  /// Checks if all values in a split map are effectively equal
  static bool isSplitEqual(Map<String, double> splitMap) {
    if (splitMap.isEmpty) return true;
    final values = splitMap.values.map((v) => (v * 10).round() / 10).toSet();
    return values.length <= 1;
  }

  /// Calculates exact amounts for each member from their percentage share
  static Map<String, double> calculateCustomSplitFromPercentages({
    required double totalAmount,
    required Map<String, double> percentages,
    List<String>? memberIds,
  }) {
    final result = <String, double>{};
    final effectiveMembers = memberIds ?? percentages.keys.toList();
    if (totalAmount <= 0 || effectiveMembers.isEmpty) return result;

    final totalPct = percentages.values.fold(0.0, (sum, p) => sum + p);
    final scale = totalPct > 0 ? totalPct : 100.0;

    double allocatedSoFar = 0.0;
    for (int i = 0; i < effectiveMembers.length; i++) {
      final mId = effectiveMembers[i];
      final pct = percentages[mId] ?? 0.0;
      if (i == effectiveMembers.length - 1) {
        final remainder = ((totalAmount - allocatedSoFar) * 100).round() / 100.0;
        result[mId] = remainder >= 0 ? remainder : 0.0;
      } else {
        final share = ((totalAmount * (pct / scale)) * 100).round() / 100.0;
        result[mId] = share;
        allocatedSoFar += share;
      }
    }
    return result;
  }

  /// Calculates percentage shares for each member from their exact amount share
  static Map<String, double> calculatePercentagesFromCustomSplit({
    required double totalAmount,
    required Map<String, double> customSplit,
  }) {
    final result = <String, double>{};
    if (totalAmount <= 0 || customSplit.isEmpty) return result;

    for (final entry in customSplit.entries) {
      final pct = (entry.value / totalAmount) * 100.0;
      final rounded = ((pct * 100).round()) / 100.0;
      result[entry.key] = rounded;
    }
    return result;
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    String? payerId,
    String? billTypeId,
    List<String>? splitAmong,
    List<String>? exemptions,
    Map<String, double>? customSplit,
    Map<String, double>? splitPercentages,
    String? whoOrBill,
    String? note,
    double? amount,
    String? date,
    String? parentId,
    double? distributionTotal,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      payerId: payerId ?? this.payerId,
      billTypeId: billTypeId ?? this.billTypeId,
      splitAmong: splitAmong ?? this.splitAmong,
      exemptions: exemptions ?? this.exemptions,
      customSplit: customSplit ?? this.customSplit,
      splitPercentages: splitPercentages ?? this.splitPercentages,
      whoOrBill: whoOrBill ?? this.whoOrBill,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      parentId: parentId ?? this.parentId,
      distributionTotal: distributionTotal ?? this.distributionTotal,
    );
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final double parsedAmount = rawAmount is num ? rawAmount.toDouble() : 0.0;

    Map<String, double>? parsedCustomSplit;
    if (json['customSplit'] is Map) {
      parsedCustomSplit = (json['customSplit'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    }

    final exemptionsList = (json['exemptions'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    final exemptSet = exemptionsList?.toSet() ?? const <String>{};

    final rawSplitAmong = json['splitAmong'];
    final cleanMembers = <String>[];
    final parsedAmounts = <String, double>{};
    final parsedPercentages = <String, double>{};

    if (rawSplitAmong is List) {
      for (int i = 0; i < rawSplitAmong.length; i++) {
        final item = rawSplitAmong[i];
        if (item is String && i + 1 < rawSplitAmong.length && rawSplitAmong[i + 1] is num) {
          final id = item.trim();
          final val = (rawSplitAmong[i + 1] as num).toDouble();
          if (!exemptSet.contains(id) && val > 0) {
            cleanMembers.add(id);
            parsedAmounts[id] = val;
          }
          i++; // skip value
        } else {
          final parsed = parseSplitItem(item);
          if (parsed.id.isNotEmpty && !exemptSet.contains(parsed.id)) {
            if (parsed.amount != null) {
              if (parsed.amount! > 0) {
                cleanMembers.add(parsed.id);
                parsedAmounts[parsed.id] = parsed.amount!;
              }
            } else if (parsed.percentage != null) {
              if (parsed.percentage! > 0) {
                cleanMembers.add(parsed.id);
                parsedPercentages[parsed.id] = parsed.percentage!;
              }
            } else {
              cleanMembers.add(parsed.id);
            }
          }
        }
      }
    }

    if (parsedAmounts.isNotEmpty) {
      parsedCustomSplit = (parsedCustomSplit != null)
          ? {...parsedCustomSplit, ...parsedAmounts}
          : parsedAmounts;
    } else if (parsedPercentages.isNotEmpty && (parsedCustomSplit == null || parsedCustomSplit.isEmpty)) {
      if (parsedAmount > 0) {
        parsedCustomSplit = calculateCustomSplitFromPercentages(
          totalAmount: parsedAmount,
          percentages: parsedPercentages,
          memberIds: cleanMembers,
        );
      }
    }

    if (parsedCustomSplit != null && parsedCustomSplit.isNotEmpty) {
      parsedCustomSplit.removeWhere((k, v) => exemptSet.contains(k) || v <= 0.0);
      if (parsedPercentages.isEmpty && parsedAmount > 0) {
        parsedPercentages.addAll(
          calculatePercentagesFromCustomSplit(
            totalAmount: parsedAmount,
            customSplit: parsedCustomSplit,
          ),
        );
      }
    }

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      payerId: json['payerId']?.toString(),
      billTypeId: json['billTypeId']?.toString(),
      splitAmong: cleanMembers.isNotEmpty ? cleanMembers : null,
      exemptions: exemptionsList,
      customSplit: parsedCustomSplit != null && parsedCustomSplit.isNotEmpty ? parsedCustomSplit : null,
      splitPercentages: parsedPercentages.isNotEmpty ? parsedPercentages : null,
      whoOrBill: json['whoOrBill']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      amount: parsedAmount,
      date: json['date']?.toString() ?? '',
      parentId: json['parentId']?.toString(),
      distributionTotal: json['distributionTotal'] != null
          ? (json['distributionTotal'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      if (parentId != null && parentId!.isNotEmpty) 'parentId': parentId,
      'type': type,
      'whoOrBill': whoOrBill.isNotEmpty
          ? whoOrBill
          : (type == 'credit' ? (payerId ?? '') : (billTypeId ?? '')),
      'amount': amount % 1.0 == 0.0 ? amount.toInt() : amount,
      'note': note,
      'date': date,
    };

    if (hasCustomSplit) {
      // Unequal split -> write exact allocated amounts into splitAmong: ["gulam 30", "raza 20"] or ["gulam 50", "raza 90"]
      map['splitAmong'] = formattedSplitAmong;
    } else if (cleanSplitMembers.isNotEmpty) {
      // Equal split -> keep it clean: ["gulam", "raza"]
      map['splitAmong'] = cleanSplitMembers;
    } else if (splitAmong != null && splitAmong!.isNotEmpty) {
      map['splitAmong'] = splitAmong;
    }

    if (distributionTotal != null) {
      map['distributionTotal'] = distributionTotal;
    }
    return map;
  }
}
