package db

import "testing"

func TestMetadataSetAndGet(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Set a value
	err := db.SetMetadata("test_key", "test_value")
	if err != nil {
		t.Fatalf("SetMetadata failed: %v", err)
	}

	// Get the value
	value, err := db.GetMetadata("test_key")
	if err != nil {
		t.Fatalf("GetMetadata failed: %v", err)
	}
	if value != "test_value" {
		t.Errorf("expected 'test_value', got '%s'", value)
	}
}

func TestMetadataGetNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Get non-existent key should return empty string, no error
	value, err := db.GetMetadata("non_existent_key")
	if err != nil {
		t.Fatalf("GetMetadata failed: %v", err)
	}
	if value != "" {
		t.Errorf("expected empty string for non-existent key, got '%s'", value)
	}
}

func TestMetadataUpdate(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Set initial value
	err := db.SetMetadata("update_key", "initial_value")
	if err != nil {
		t.Fatalf("SetMetadata failed: %v", err)
	}

	// Update to new value
	err = db.SetMetadata("update_key", "updated_value")
	if err != nil {
		t.Fatalf("SetMetadata (update) failed: %v", err)
	}

	// Verify updated value
	value, err := db.GetMetadata("update_key")
	if err != nil {
		t.Fatalf("GetMetadata failed: %v", err)
	}
	if value != "updated_value" {
		t.Errorf("expected 'updated_value', got '%s'", value)
	}
}

func TestMetadataDelete(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Set a value
	err := db.SetMetadata("delete_key", "to_be_deleted")
	if err != nil {
		t.Fatalf("SetMetadata failed: %v", err)
	}

	// Delete it
	err = db.DeleteMetadata("delete_key")
	if err != nil {
		t.Fatalf("DeleteMetadata failed: %v", err)
	}

	// Verify it's gone
	value, err := db.GetMetadata("delete_key")
	if err != nil {
		t.Fatalf("GetMetadata after delete failed: %v", err)
	}
	if value != "" {
		t.Errorf("expected empty string after delete, got '%s'", value)
	}
}

func TestMetadataDeleteNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Deleting non-existent key should not error
	err := db.DeleteMetadata("non_existent_key")
	if err != nil {
		t.Fatalf("DeleteMetadata on non-existent key should not error: %v", err)
	}
}

func TestMetadataEmptyValue(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Set empty value
	err := db.SetMetadata("empty_key", "")
	if err != nil {
		t.Fatalf("SetMetadata with empty value failed: %v", err)
	}

	// Get should return empty string
	value, err := db.GetMetadata("empty_key")
	if err != nil {
		t.Fatalf("GetMetadata failed: %v", err)
	}
	if value != "" {
		t.Errorf("expected empty string, got '%s'", value)
	}
}

func TestMetadataMultipleKeys(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Set multiple keys
	keys := map[string]string{
		"key1": "value1",
		"key2": "value2",
		"key3": "value3",
	}

	for k, v := range keys {
		if err := db.SetMetadata(k, v); err != nil {
			t.Fatalf("SetMetadata(%s) failed: %v", k, err)
		}
	}

	// Verify all keys
	for k, expected := range keys {
		value, err := db.GetMetadata(k)
		if err != nil {
			t.Fatalf("GetMetadata(%s) failed: %v", k, err)
		}
		if value != expected {
			t.Errorf("key %s: expected '%s', got '%s'", k, expected, value)
		}
	}
}
