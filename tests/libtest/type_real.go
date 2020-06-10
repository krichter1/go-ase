package libtest

import (
	"database/sql"

	"testing"
)

// DoTestReal tests the handling of the Real.
func DoTestReal(t *testing.T) {
	TestForEachDB("TestReal", t, testReal)
	//
}

func testReal(t *testing.T, db *sql.DB, tableName string) {
	pass := make([]interface{}, len(samplesReal))
	mySamples := make([]float64, len(samplesReal))

	for i, sample := range samplesReal {

		mySample := sample

		pass[i] = mySample
		mySamples[i] = mySample
	}

	rows, teardownFn, err := SetupTableInsert(db, tableName, "real", pass...)
	if err != nil {
		t.Errorf("Error preparing table: %v", err)
		return
	}
	defer rows.Close()
	defer teardownFn()

	i := 0
	var recv float64
	for rows.Next() {
		err = rows.Scan(&recv)
		if err != nil {
			t.Errorf("Scan failed on %dth scan: %v", i, err)
			continue
		}

		if recv != mySamples[i] {

			t.Errorf("Received value does not match passed parameter")
			t.Errorf("Expected: %v", mySamples[i])
			t.Errorf("Received: %v", recv)
		}

		i++
	}

	if err := rows.Err(); err != nil {
		t.Errorf("Error preparing rows: %v", err)
	}
}
