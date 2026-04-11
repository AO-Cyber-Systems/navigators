package navigators

import (
	"math"

	"github.com/google/uuid"
)

// VoterLocation holds a voter's geographic position and basic info for walk list generation.
type VoterLocation struct {
	ID        uuid.UUID
	Lat       float64
	Lng       float64
	FirstName string
	LastName  string
	Address   string
}

// generateWalkList orders voters by nearest-neighbor greedy algorithm starting from (startLat, startLng).
// Returns voters in walk order. O(n^2) -- suitable for turf-sized datasets (100-2000 voters).
func generateWalkList(voters []VoterLocation, startLat, startLng float64) []VoterLocation {
	if len(voters) == 0 {
		return voters
	}

	n := len(voters)
	result := make([]VoterLocation, 0, n)
	visited := make([]bool, n)

	curLat, curLng := startLat, startLng

	for range n {
		bestIdx := -1
		bestDist := math.MaxFloat64

		for i := range n {
			if visited[i] {
				continue
			}
			d := haversine(curLat, curLng, voters[i].Lat, voters[i].Lng)
			if d < bestDist {
				bestDist = d
				bestIdx = i
			}
		}

		if bestIdx < 0 {
			break
		}

		visited[bestIdx] = true
		result = append(result, voters[bestIdx])
		curLat = voters[bestIdx].Lat
		curLng = voters[bestIdx].Lng
	}

	return result
}

// haversine returns the great-circle distance in kilometers between two points.
func haversine(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadiusKm = 6371.0

	dLat := degreesToRadians(lat2 - lat1)
	dLng := degreesToRadians(lng2 - lng1)

	lat1Rad := degreesToRadians(lat1)
	lat2Rad := degreesToRadians(lat2)

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusKm * c
}

func degreesToRadians(deg float64) float64 {
	return deg * math.Pi / 180.0
}
