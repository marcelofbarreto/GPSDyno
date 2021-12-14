//
//  ViewController.swift
//  teste
//
//  Created by Marcelo Ferreira Barreto on 24/11/20.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate
{
    @IBOutlet weak var lbInstant: UILabel!
    @IBOutlet weak var pvInstantCV: UIProgressView!
    @IBOutlet weak var lbInstantCV: UILabel!
    @IBOutlet weak var lbMaxCV: UILabel!
    @IBOutlet weak var lbDebug: UILabel!
    @IBOutlet weak var tvPower: UITextView!
    @IBOutlet weak var tfWeight: UITextField!
    @IBOutlet weak var lbSpeed: UILabel!
    @IBOutlet weak var lbAccuracy: UILabel!
    
    let locationManager = CLLocationManager()    
    var varLastSpeed:CLLocationSpeed = 0;
    var varLastTimeStamp:Date = Date()
    
    var update = 0
    
    var varMaxPower:Double = 0
    var varWeight:Double = 0
    
    var varMaxPowerPV:Double = 100
    
    //peak power indicator
    var varPeakPower:Double = 0
    var varTimerPeak:Timer? = nil

    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        //enable location services and get best Accuracy possible
        if CLLocationManager.locationServicesEnabled()
        {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.startUpdatingLocation()
        }
        varWeight = Double(tfWeight.text ?? "0") ?? 0
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        UIApplication.shared.isIdleTimerDisabled = true // do not sleep
        
        let weight = UserDefaults.standard.double(forKey:"weight")//retrieve saved last weight
        if weight > 0
        {
            varWeight = weight
            tfWeight.text = "\(Int(varWeight))"
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        UIApplication.shared.isIdleTimerDisabled = false //disable it so device can sleep
        UserDefaults.standard.setValue(varWeight, forKey: "weight")//save last weight used
    }
    
    //location manager delegate, here is where we get the GPS measurements
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        let vLocation = locations.last!
        //do not lock the location loop
        DispatchQueue.main.async
        {
            //just to show the GPS precision, speed and etc
            self.lbAccuracy.text = "Precision:\(vLocation.horizontalAccuracy) m"
            if(vLocation.horizontalAccuracy < 10)
            {
                self.lbAccuracy.textColor = .black
            }
            else if(vLocation.horizontalAccuracy < 20)
            {
                self.lbAccuracy.textColor = .yellow
            }
            else
            {
                self.lbAccuracy.textColor = .red
            }
                       
            if vLocation.speed > 0
            {
                self.lbSpeed.text = "Speed:\( vLocation.speed  * 3.6) km/h Accuracy:\(vLocation.speedAccuracy * 3.6) km/h"
                self.lbSpeed.text = String(format: "Spd: %.1f km/h Prec.: %.1f km/h", ( vLocation.speed  * 3.6),(vLocation.speedAccuracy*3.6))
            }
        }
        
        if(vLocation.speed > 0)
        {
            //acceleration  a = (v-v0)/(t - t0)
            let a = (vLocation.speed - varLastSpeed)/vLocation.timestamp.timeIntervalSince(varLastTimeStamp)
            
            //Power (P) = Mass (M) x Acceleration (A) x Velocity (V) -> in watts
            let Power = varWeight * a * vLocation.speed
            
            //Convert it to CV divide for 735.49875 or HP  divide for 745,7
            let PowerInCv = Power / 735.49875
            
            //do not get negative values, because I want it this way, you can change later
            if vLocation.speed >= varLastSpeed
            {
                //log the maximum power
                if PowerInCv > varMaxPowerPV
                {
                    varMaxPowerPV = PowerInCv
                }
                                
                //use main thread to avoid issues here
                DispatchQueue.main.async {
                    
                    //put all in interface
                    self.lbInstant.text = String(format: "Instant pow: %.2f cv", PowerInCv)
                    self.lbInstant.textColor = .black
                    
                    if PowerInCv > self.varMaxPower
                    {
                        self.varMaxPower = PowerInCv
                        self.lbMaxCV.text = String(format: "MaxCV: %.2f", self.varMaxPower)
                    }
                    
                    if PowerInCv > self.varPeakPower
                    {
                        // my "ugly log", this is just a "POC" after all
                        let text = self.tvPower.text ?? ""
                        self.tvPower.text = String(format: "MP: %.2f cv Spd: %.2f Acc:%.2f m/s^2 Prec:%.2fm\n", PowerInCv,(vLocation.speed*3.6),a,vLocation.horizontalAccuracy) + text
                        self.varPeakPower = PowerInCv
                        if self.varTimerPeak != nil
                        {
                            self.varTimerPeak?.invalidate()
                            self.varTimerPeak = nil
                        }
                        //update progress, just to make it a little more pleasent
                        let pvDial = self.varPeakPower / self.varMaxPowerPV
                        
                        self.lbInstantCV.text = "\(Int(self.varPeakPower)) cv"
                        self.pvInstantCV.layer.removeAllAnimations()
                        UIView.animate(withDuration: 0.1)
                        {
                            //change colors
                            if pvDial < 0.5
                            {
                                self.pvInstantCV.progressTintColor = .green
                            }
                            else if pvDial < 0.8
                            {
                                self.pvInstantCV.progressTintColor = .yellow
                            }
                            else
                            {
                                self.pvInstantCV.progressTintColor = .red
                            }
                            self.pvInstantCV.progress = Float(pvDial)
                        }
                        
                        //clear the power peak
                        self.varTimerPeak = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block:
                        { (tm) in
                            self.varTimerPeak = nil
                            self.varPeakPower = 0
                            self.lbInstantCV.text = "\(Int(self.varPeakPower)) cv"
                            self.pvInstantCV.layer.removeAllAnimations()
                            UIView.animate(withDuration: 0.1) {
                                self.pvInstantCV.progress = Float(0)
                                self.pvInstantCV.progressTintColor = .green
                            }
                        })
                    }
                }
            }
            else{
                DispatchQueue.main.async {
                    self.lbInstant.text = String(format: "Instant pow: %.2f cv", PowerInCv)
                    self.lbInstant.textColor = .red
                }
            }
            varLastSpeed = vLocation.speed
        }
        else
        {
            varLastSpeed = 0;
            DispatchQueue.main.async {
                self.lbInstant.text = "0"
            }
        }
        
        //finishing touches
        //save the last time interval
        varLastTimeStamp = vLocation.timestamp
        
        update = update + 1 // just the current data update, for logs only
        
        DispatchQueue.main.async {
            self.lbDebug.text =  "Update:\(self.update)"
        }
    }

    //keyboard and stuff
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        return true
    }
    
    @IBAction func onOkClick(_ sender: Any)
    {
        tfWeight.resignFirstResponder()
    }
    
    //reset interface
    @IBAction func onResetClick(_ sender: Any)
    {
        varMaxPower = 0
        varMaxPowerPV = 100
        lbMaxCV.text = "0"
        pvInstantCV.progress = 0
        pvInstantCV.progressTintColor = .green
        self.tvPower.text =  ""
    }
    
}

