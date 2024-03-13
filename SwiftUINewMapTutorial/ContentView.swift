//
//  ContentView.swift
//  SwiftUINewMapTutorial
//
//  Created by Hakob Ghlijyan on 11.03.2024.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var cameraPosition: MapCameraPosition = .region(.userRegion)
    @State private var searchText: String = ""
    @State private var results: [MKMapItem] = []
    @State private var mapSelection: MKMapItem?
    @State private var showDetails: Bool = false
    @State private var getDirections: Bool = false
    @State private var routeDisplaying: Bool = false
    @State private var route: MKRoute?
    @State private var routeDestination: MKMapItem?
    
    var body: some View {
        Map(position: $cameraPosition, selection: $mapSelection) {
            Annotation("My Home", coordinate: .userLocation) {
                MarkerCircleView()
            }
            ForEach(results, id: \.self) { item in
                if routeDisplaying {
                    if item == routeDestination {
                        let placemark = item.placemark
                        Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                    }
                } else {
                    let placemark = item.placemark
                    Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                }
            }
            if let route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 6)
            }
        }
        .overlay(alignment: .top, content: {
            TextField("Search for a location", text: $searchText)
                .font(.subheadline)
                .padding(12)
                .background(.white)
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding()
                
        })
        .onSubmit(of: .text) {
            print("Search for a locations with query: \(searchText)")
            Task {
                await searchPlaces()
            }
        }
        .onChange(of: mapSelection, { oldValue, newValue in
            showDetails = newValue != nil
        })
        .onChange(of: getDirections, { oldValue, newValue in
            if newValue {
                fetchRoute()
            }
        })
        .popover(isPresented: $showDetails, content: {
            LocationDetailView(mapSelection: $mapSelection, show: $showDetails, getDirections: $getDirections)
                .presentationCompactAdaptation(.sheet)
                .presentationDetents([.medium])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(12)
                
        })
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapUserLocationButton()
        }
    }
}

#Preview {
    ContentView()
}

extension ContentView {
    
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = .userRegion
        let results = try? await MKLocalSearch(request: request).start()
        self.results = results?.mapItems ?? []
    }
    
    func fetchRoute() {
        if let mapSelection {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: .init(coordinate: .userLocation))
            request.destination = mapSelection
            
            Task {
                let result = try? await MKDirections(request: request).calculate()
                route = result?.routes.first
                routeDestination = mapSelection
                
                withAnimation(.snappy) {
                    routeDisplaying = true
                    showDetails = false
                    
                    if let rect = route?.polyline.boundingMapRect, routeDisplaying {
                        cameraPosition = .rect(rect)
                    }
                }
            }
        }
    }
}

//MARK: - Current User Location
extension CLLocationCoordinate2D {
    static var userLocation: CLLocationCoordinate2D {
//        .init(latitude: 40.205600, longitude: 44.526530) //Yerevan
        .init(latitude: 25.7602, longitude: -80.1959)  //Miami
    }
}

//MARK: - Location Size
extension MKCoordinateRegion {
    static var userRegion: MKCoordinateRegion {
        .init(center: .userLocation, latitudinalMeters: 2000, longitudinalMeters: 2000)
    }
}

struct MarkerCircleView: View {
    var body: some View {
        ZStack {
            Circle()
                .frame(width: 32, height: 32)
                .foregroundStyle(.blue.opacity(0.25))
            Circle()
                .frame(width: 20, height: 20)
                .foregroundStyle(.white)
            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(.blue)
        }
    }
}

struct LocationDetailView: View {
    @Binding var mapSelection: MKMapItem?
    @Binding var show: Bool
    @State private var lookAroundScene: MKLookAroundScene?
    @Binding var getDirections: Bool
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(mapSelection?.placemark.name ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(mapSelection?.placemark.title ?? "")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                        .padding(.trailing)
                }
                Spacer()
                Button(action: {
                    show.toggle()
                    mapSelection = nil
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.gray, Color(.systemGray6))
                })
            }
            .padding(.horizontal)
            .padding()
            
            if let scene = lookAroundScene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding()
            } else {
                ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                    .font(.callout)
            }
            //Buttons
            HStack(spacing: 24) {
                Button {
                    if let mapSelection {
                        mapSelection.openInMaps()
                    }
                } label: {
                    Text("Open in Map")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 170, height: 48)
                        .background(.green)
                        .cornerRadius(12)
                }
                Button {
                    getDirections = true
                    show = false
                } label: {
                    Text("Get Directions")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 170, height: 48)
                        .background(.blue)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .onAppear(perform: {
            fetchLookAroundPreview()
            print("DEBUG: Did call on appear")
        })
        .onChange(of: mapSelection) { oldValue, newValue in
            print("DEBUG: Did call on change")
            fetchLookAroundPreview()
        }
        .padding()
    }
}

extension LocationDetailView {
    func fetchLookAroundPreview() {
        if let mapSelection {
            lookAroundScene = nil
            Task {
                let request = MKLookAroundSceneRequest(mapItem: mapSelection)
                lookAroundScene = try? await request.scene
            }
        }
    }
}
