class ColdCardGeneric {
  ColdCardGeneric({
    this.chain,
    this.xpub,
    this.xfp,
    this.account,
    this.bip49,
    this.bip44,
    this.bip84,
  });
  ColdCardGeneric.fromJson(Map<String, dynamic> json) {
    chain = json['chain'] as String;
    xpub = json['xpub'] as String;
    xfp = json['xfp'] as String;
    account = json['account'] as int;
    bip49 = json['bip49'] != null
        ? Bip49.fromJson(json['bip49'] as Map<String, dynamic>)
        : null;
    bip44 = json['bip44'] != null
        ? Bip44.fromJson(json['bip44'] as Map<String, dynamic>)
        : null;
    bip84 = json['bip84'] != null
        ? Bip49.fromJson(json['bip84'] as Map<String, dynamic>)
        : null;
  }
  String? chain;
  String? xpub;
  String? xfp;
  int? account;
  Bip49? bip49;
  Bip44? bip44;
  Bip49? bip84;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['chain'] = chain;
    data['xpub'] = xpub;
    data['xfp'] = xfp;
    data['account'] = account;
    if (bip49 != null) {
      data['bip49'] = bip49!.toJson();
    }
    if (bip44 != null) {
      data['bip44'] = bip44!.toJson();
    }
    if (bip84 != null) {
      data['bip84'] = bip84!.toJson();
    }
    return data;
  }

  String get bip84Policy =>
      'pk([${xfp!.toLowerCase()}/84h/${(chain == 'XTN') ? "1h" : "0h"}/${account}h}]${bip84!.xpub}/*)';
  String get bip49Policy =>
      'pk([${xfp!.toLowerCase()}/49h/${(chain == 'XTN') ? "1h" : "0h"}/${account}h}]${bip49!.xpub}/*)';
  String get bip44Policy =>
      'pk([${xfp!.toLowerCase()}/44h/${(chain == 'XTN') ? "1h" : "0h"}/${account}h}]${bip44!.xpub}/*)';
}

class Bip49 {
  Bip49({this.xpub, this.first, this.deriv, this.xfp, this.name, this.sPub});
  Bip49.fromJson(Map<String, dynamic> json) {
    xpub = json['xpub'] as String;
    first = json['first'] as String;
    deriv = json['deriv'] as String;
    xfp = json['xfp'] as String;
    name = json['name'] as String;
    sPub = json['_pub'] as String;
  }
  String? xpub;
  String? first;
  String? deriv;
  String? xfp;
  String? name;
  String? sPub;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['xpub'] = xpub;
    data['first'] = first;
    data['deriv'] = deriv;
    data['xfp'] = xfp;
    data['name'] = name;
    data['_pub'] = sPub;
    return data;
  }
}

class Bip44 {
  Bip44({this.xpub, this.first, this.deriv, this.xfp, this.name});
  Bip44.fromJson(Map<String, dynamic> json) {
    xpub = json['xpub'] as String;
    first = json['first'] as String;
    deriv = json['deriv'] as String;
    xfp = json['xfp'] as String;
    name = json['name'] as String;
  }
  String? xpub;
  String? first;
  String? deriv;
  String? xfp;
  String? name;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['xpub'] = xpub;
    data['first'] = first;
    data['deriv'] = deriv;
    data['xfp'] = xfp;
    data['name'] = name;
    return data;
  }
}

class Bip84 {
  Bip84({this.xpub, this.first, this.deriv, this.xfp, this.name});
  Bip84.fromJson(Map<String, dynamic> json) {
    xpub = json['xpub'] as String;
    first = json['first'] as String;
    deriv = json['deriv'] as String;
    xfp = json['xfp'] as String;
    name = json['name'] as String;
  }
  String? xpub;
  String? first;
  String? deriv;
  String? xfp;
  String? name;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['xpub'] = xpub;
    data['first'] = first;
    data['deriv'] = deriv;
    data['xfp'] = xfp;
    data['name'] = name;
    return data;
  }
}
