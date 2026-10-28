class Drama {
  final String id;
  final String name;
  final String pic;
  final String remark;

  const Drama({
    required this.id,
    required this.name,
    required this.pic,
    required this.remark,
  });

  @override
  String toString() => 'Drama(id: $id, name: $name)';
}
