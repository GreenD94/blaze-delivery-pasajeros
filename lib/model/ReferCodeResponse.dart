class ReferCodeResponse {
  String? refCode;
  bool? status;
  String? message;

  ReferCodeResponse({this.status, this.message, this.refCode});

  ReferCodeResponse.fromJson(Map<String, dynamic> json) {
    refCode = json['ref_code'];
    status = json['status'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['ref_code'] = this.refCode;
    data['status'] = this.status;
    data['message'] = this.message;
    return data;
  }
}
