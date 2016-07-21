#### Usage
The script is meant to be run as a rails runner from within 
Supply Chain. It relies on several documents.

* SupplierProperty
* RoomCategory
* RoomTypeMapping
* UserTranslatedText

```
  rails r ./room_category_import/bin/import file1.csv file2.csv file3.csv
```

This will do the following:

* Find a supplier property based on the supplier_code, subsupplier_code, and
  property_code.
* Initialize or find `room_category` with an id from the `room_code`
* Initialize or find a `room_type_mapping` with the `room_type_id` and
  `supplier_property_id`. The `room_type_id` is created from:

```
Adapter.for(supplier_code.to_sym).room_type_uuid(supplier_property.property_code, room_category.room_code)
```

* Add an `UserTranslatedText` english name translation to the room_category if
  it doesn't have one
