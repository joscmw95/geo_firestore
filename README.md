# GeoFirestore
GeoFirestore implementation for Flutter to do location based queries with Firestore.

### GeoFirestore

A `GeoFirestore` object is used to read and write geo location data to your Firestore database and to create queries. To create a new `GeoFirestore` instance you need to attach it to a Firestore collection reference:

```dart
Firestore firestore = Firestore.instance;
GeoFirestore geoFirestore = GeoFirestore(firestore.collection('places'));
```

#### Setting location data

To set the location of a document simply call the `setLocation` method:

```dart
await geoFirestore.setLocation('tl0Lw0NUddQx5a8kXymO', GeoPoint(37.7853889, -122.4056973));
```

To remove a location and delete the location from your database simply call:

```dart
await geoFirestore.removeLocation('tl0Lw0NUddQx5a8kXymO');
```

#### Retrieving a location

If the document is not present in GeoFirestore, the callback will be called with `null`. If an error occurred, the callback is passed the error and the location will be `null`.

```dart
final location = await geoFirestore.getLocation('tl0Lw0NUddQx5a8kXymO');
print('Location for this document is $location.latitude, $location.longitude');
```

### Geo Queries

GeoFirestore allows you to query all documents within a geographic area using the method `getAtLocation`.

```dart
final queryLocation = GeoPoint(37.7853889, -122.4056973)

// creates a new query around [37.7832, -122.4056] with a radius of 0.6 kilometers
final List<DocumentSnapshot> documents = await geoFirestore.getAtLocation(queryLocation, 0.6);
documents.forEach((document) {
  print(document.data);
});
```

This library is inspired mostly a port of [GeoFirestore-Android](https://github.com/imperiumlabs/GeoFirestore-Android).