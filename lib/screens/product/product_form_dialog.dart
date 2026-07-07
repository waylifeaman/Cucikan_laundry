import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductFormDialog extends StatefulWidget {
  final String outletId;
  final DocumentSnapshot? product;

  const ProductFormDialog({super.key, required this.outletId, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late TextEditingController nameController;

  late TextEditingController regularPriceController;
  late TextEditingController expressPriceController;
  late TextEditingController kilatPriceController;

  late TextEditingController regularDurationController;
  late TextEditingController expressDurationController;
  late TextEditingController kilatDurationController;

  String productType = 'Kiloan';
  String regularDurationType = 'hari';
  String expressDurationType = 'hari';
  String kilatDurationType = 'jam';

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    regularDurationType = product?['regular_duration_type'] ?? 'hari';

    expressDurationType = product?['express_duration_type'] ?? 'hari';

    kilatDurationType = product?['kilat_duration_type'] ?? 'jam';

    nameController = TextEditingController(text: product?['name'] ?? '');

    productType = product?['product_type'] ?? 'Kiloan';

    regularPriceController = TextEditingController(
      text: product?['regular_price']?.toString() ?? '',
    );

    expressPriceController = TextEditingController(
      text: product?['express_price']?.toString() ?? '',
    );

    kilatPriceController = TextEditingController(
      text: product?['kilat_price']?.toString() ?? '',
    );

    regularDurationController = TextEditingController(
      text: product?['regular_duration']?.toString() ?? '',
    );

    expressDurationController = TextEditingController(
      text: product?['express_duration']?.toString() ?? '',
    );

    kilatDurationController = TextEditingController(
      text: product?['kilat_duration']?.toString() ?? '',
    );
  }

  Future<void> saveProduct() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama produk tidak boleh kosong')),
      );
      return;
    }

    final data = {
      'name': nameController.text.trim(),
      'product_type': productType,
      'regular_price': int.tryParse(regularPriceController.text) ?? 0,
      'regular_duration': int.tryParse(regularDurationController.text) ?? 0,
      'regular_duration_type': 'hari',
      'express_price': int.tryParse(expressPriceController.text) ?? 0,
      'express_duration': int.tryParse(expressDurationController.text) ?? 0,
      'express_duration_type': 'hari',
      'kilat_price': int.tryParse(kilatPriceController.text) ?? 0,
      'kilat_duration': int.tryParse(kilatDurationController.text) ?? 0,
      'kilat_duration_type': 'jam',
      'isActive': true,
      'isDeleted': false,
      'created_at': Timestamp.now(),
    };

    try {
      if (widget.product == null) {
        await FirebaseFirestore.instance
            .collection('outlets')
            .doc(widget.outletId)
            .collection('products')
            .add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('outlets')
            .doc(widget.outletId)
            .collection('products')
            .doc(widget.product!.id)
            .update(data);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan produk: $e')));
    }
  }

  Widget buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Tambah Produk' : 'Edit Produk',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF152C4A),
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: productType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Kiloan', child: Text('Kiloan')),
                  DropdownMenuItem(value: 'Satuan', child: Text('Satuan')),
                ],
                onChanged: (value) {
                  setState(() {
                    productType = value!;
                  });
                },
              ),

              const SizedBox(height: 15),

              const Text(
                'REGULER',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF152C4A),
                ),
              ),

              buildField('Harga Reguler', regularPriceController),

              buildField('Durasi Reguler Hari', regularDurationController),

              const SizedBox(height: 10),

              const Text(
                'EXPRESS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF152C4A),
                ),
              ),

              buildField('Harga Express', expressPriceController),

              buildField('Durasi Express Hari', expressDurationController),

              const SizedBox(height: 10),

              const Text(
                'KILAT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF152C4A),
                ),
              ),

              buildField('Harga Kilat', kilatPriceController),

              buildField('Durasi Kilat Jam', kilatDurationController),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(onPressed: saveProduct, child: const Text('Simpan')),
      ],
    );
  }
}
