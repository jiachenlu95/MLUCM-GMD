           program column

!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     +    by A. Martilli,     CIEMAT  SP 2040 MADRID                  +
!     +                        phone: ++34-9-13-46-62-99               +
!     +                        email:alberto.martilli@ciemat.es        +
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     +  Modified by S. Krayenhoff,  UBC      Mar 2013 - Jun 2016      +
!     +                        email:scott.krayenhoff@alumni.ubc.ca    +
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     +  Modified by N. Nazarian, Singapore-MIT/UNSW                   +
!     +  Jan 2017-Sept 2019                                            +
!     +                        email: n.nazarian@unsw.edu.au           +
!     +                               nazarian@mit.edu                 +
!     +                               nenazarian@gmail.com             +
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     +  Modified by J. Lu,       UNSW                                 +
!     +  Nov 2021-Mar 2023                                             +
!     +                        email: jiachen.lu@unsw.edu.au           +
!     +                               jiachensc@gmail.com              +
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     Goal: To solve the drag and vertical diffusion in a column for   +
!           neutral case.

           implicit none
           integer nzm,nlp,nzc,nscen
           parameter (nzm=128)    ! number of total levels in the vertical
           parameter (nzc=16)    ! number of canopy levels in the vertical (only valid for cnst)
           parameter (nlp=1)
! flow variables
           real vx(nzm) ! x component of the wind
           real vy(nzm) ! y component of the wind
           real tke(nzm) ! tke
           real trc(nzm) ! trc
           real dpdx,dpdy ! external pressure gradient in x and y direction
           real utau_x,utau_y ! utau 
! variable needed in the calculation of the TKE and vertical diffusion  
           real dlk(nzm) ! mixing length
           real dls(nzm) ! dissipation length scale
           real cdz(nzm+1) ! vertical diffusion coefficients
           real ceps,ck,cmu ! constants for the k-l scheme
!           parameter (ceps=1/1.4,ck=0.4,cmu=0.09)
! variables needed in the resolution of the diffusion equation: here source/sinks for a generic variable c are defined as c*srim_c+srex_c
           real srim_vx(nzm) ! implicit part of the source/sinks terms of v1
           real srim_vy(nzm) ! implicit part of the source/sinks terms of v2
           real srim_tke(nzm),sh(nzm),td(nzm) ! implicit part of the source/sinks terms of tke
           real srim_trc(nzm) ! implicit part of the source/sinks terms of tracer
           real srex_vx(nzm) ! implicit part of the source/sinks terms of v1
           real srex_vy(nzm) ! implicit part of the source/sinks terms of v2
           real srex_tke(nzm) ! implicit part of the source/sinks terms of tke
           real srex_trc(nzm) ! implicit part of the source/sinks terms of tracer
           real vl(nzm) ! fraction of air in each cell
           real sf(nzm+1) ! fraction of air at the interface between cells
! drag coefficient
           real cdragx(nzm),cdragy(nzm) ! drag coefficient in x and y direction           
! building information
           real ss(nzm+1) ! ss(iz)=probability to have a building of height z(iz)
           real pb(nzm+1) ! pb(iz)=probbaility to have a building taller or equal to z(iz)
           real wx,wy ! distance between buildings at street level in the x and y direction respectively
           real bx,by ! building dimension in the x and y direction respectively
           real hmean,Hmax ! mean building height
           real lpz(nzm) ! lp profile
! emission at surface
           real emi
! numerical parameters
           integer nz ! number of vertical levels
           real dz ! vertical resolution
           real z(nzm+1) ! height of the faces of the numerical grid
           real dt ! time step

           integer iz ! loop index for vertical
           integer it ! loop index for time
           integer ilp ! loop index for lambdaP (i.e. groups of scenarios with same lambdaP)
           real time ! time from the start
           real time_pr ! time from the last print
           real time_max ! total time of the simulation
           integer ntime ! total number of timesteps
           real prtime ! frequency of output
! output variables 
           real uw(nzm+1) ! turbuelnt flux of vx
           real duwdz(nzm) ! vertical derivative of the turbulent flux of vx
           real vw(nzm+1) ! turbuelnt flux of vy
           real dvwdz(nzm) ! vertical derivative of the turbulent flux of vy
           real wtke(nzm+1) ! turbuelnt flux of tke
           real dwtkedz(nzm) ! vertical derivative of the turbulent flux of tke
           real wtrc(nzm+1) ! turbuelnt flux of tracer
           real dwtrcdz(nzm) ! vertical derivative of the turbulent flux of tracer
           

! working
           real uwm,wtrcm,lad_max
           real cd_noveg(nlp,nzm) ! drag coefficient for the no veg case
           real cd_noveg1(nlp,nzm) ! drag coefficient for the no veg case
           real cdrel(nzm) ! drag coefficient value relative to no veg case
           real cdrel1(nzm) ! drag coefficient value relative to no veg case
           real lad(nzm) ! foliage density profile
           real lad_in(nzm) ! foliage density profile for the current scenario
           real leps_o_ceps_noveg(nlp,nzm) ! length scale (eps) divided by Ceps for the no veg case
           real leps_o_ceps_rel(nzm) ! length scale (eps) divided by Ceps relative to no veg case
           real dls_o_ceps(nzm) ! length scale (eps) divided by Ceps for the current case

           real cdragveg,cdragveg1,cdragveg2,cdragx1(nzm),cdragy1(nzm),zh
           real cdrel_tot,cdeq(nzm),leps_o_ceps(nzm),lambdap
           logical no_cdragveg,no_cdragveg1,no_cdragveg2,novegdrag,novegdrag1,noleps
           logical no_cdragbld,no_cdragbld1
		   
! --------------------------------------------
! NN. April 2017: Added to 1) introduce new output files, and 2) include header line in output file     
! c OPEN OUTPUT FILES
       open(unit=68,file='output_final.out')
       open(unit=001,file='topo.out')
       open(unit=002,file='TKEbudget.out')
       open(unit=003,file='Mombudget.out')       
       open(unit=30,file='calc_par.out')
!   --- Can potentially add a flag here that disables write to this file. 
       open(unit=37,file='CkLkM_verPro.out')
!      format 
        2001 format ( 8(A,7X)) 
        2011 format (1x,2(A,4X))
! --------------------------------------------
! --------------------------- Alternative input file		   
! --------------- NN. May 2017 - namelist format can be added to allow modification 
! --------------- of input parameters outside of the code in the inupdate.in file. 
! --------------- This requires that parameters of type real to be changed 
! --------------- to allocatble format. 
!        Ex: real dlk(nzm) --> real,allocatable,dimension(:) :: dlk
!        namelist /inipar/ nzm, nzc, nlp, nscen
!      open(444,file='inupdate.in',status='OLD',recl=80,
!      &      delim='APOSTROPHE', FORM='FORMATTED')
!      read(444,nml=inipar)
! --------------------------------------------
   
! --------------------------- This section can be uncommented if specification of trees (lad profile) is of focus
! read cases
!          open(unit=75,file='z.out')
!           read(75,*)(z(iz),iz=1,nzm)
!           write(6,*)'z =',z
!                 close(75)

!          open(unit=75,file='lad.out')
!           do is=1,nscen
!            read(75,*)(lad(is,iz),iz=1,nzm)
!           enddo
!                 close(75)
! --------------------------------------------


! ---------------------------- Input file for lambdaP values 
          open(unit=75,file='lambdaP.dat')
            read(75,*)lambdap
         close(75)
! --------------------------------------------

          cdragveg=0.2
          cdragveg1=0.2
          cdragveg2=0.2


! Change one of these to "true" to disable a term related to the addition of vegetation

! drag due to vegetation in the momentum equation:
          no_cdragveg=.true.
! production of TKE by vegetation drag:
          no_cdragveg1=.true.
! enhanced dissipation of TKE by leaves and branches:
          no_cdragveg2=.true.


! These are not currently set up in this version of the model:
! altered drag coefficient of buildings due to addition of vegetation (affecting U drag):
          novegdrag=.true.
! altered drag coefficient of buildings due to addition of vegetation (affecting TKE production):
          novegdrag1=.true.
! altered length scales due to presence of vegetation:
          noleps=.true.


! Change one of these to "true" to disable a term related to the addition of buildings

! drag due to buildings:
          no_cdragbld=.false.
! production of TKE by building drag
          no_cdragbld1=.false.
! altered length scales due to presence of buildings............?


          if(no_cdragveg) cdragveg=0. 
          if(no_cdragveg1) cdragveg1=0.
          if(no_cdragveg2) cdragveg2=0.


! read the input, define the mesh and obstacle paramters and intialize
           call read_input(nzm,nz,z,dz,dt,time_max,ntime,prtime,utau_x,utau_y,dpdx,dpdy,&
                           pb,ss,wx,wy,bx,by,hmean,Hmax,vl,sf,lpz)
				   

           write(6,*)'Lp =',lambdaP
!           lad_max=0.
!           do iz=1,nzm
!            if(lad(is,iz).gt.lad_max) lad_max=lad(is,iz)
!            lad_in(iz)=lad(is,iz)
!           enddo

           do iz=1,nzm
            lambdap=bx*bx/(bx+wx)**2.
           enddo

           do iz=1,nzm
           !vl(iz)=1-lpz(iz)*pb(iz+1)
           !sf(iz)=1-lpz(iz)*ss(iz)
vl(iz)=1-lambdap*pb(iz) ! 1-lp
sf(iz)=1-lambdap*ss(iz) ! all 1 except iz=17
enddo
!write(*,*) vl
!write(6,*)'iz,sf,vl',iz,sf(iz),vl(iz)
!write(*,*) vl(1),vl(2),vl(3),vl(4)
!write(*,*) sf(1),sf(2),sf(3),sf(4)

! compute the drag coefficent and the length scales

          call drag_length(nzm,nz,z,bx,by,wx,wy,hmean,Hmax,lambdap,ceps,&
ck,cmu,cdragx,cdragy,dls,dlk,lpz)

          do iz=1,nzc
           cdragx1(iz)=cdragx(iz)
           cdragy1(iz)=cdragy(iz)
                   if(no_cdragbld1) then
            cdragx1(iz)=0.
            cdragy1(iz)=0.
           endif
                   if(no_cdragbld) then
            cdragx(iz)=0.
            cdragy(iz)=0.
           endif
          enddo


! initialize vx,vy,tke - just put some value, the code should forget it since we impose a pressure gradient
           vx=(dpdx/max(cdragx(1),0.1)/lambdap)**.5
           vy=(dpdy/max(cdragy(1),0.1)/lambdap)**.5
           trc=100.
           tke=0.1
           cdz=0.1
           emi=1.
           time=0.
           time_pr=0.
           

! start the loop on time 
           do it=1,ntime
            srex_vx=0.
            srim_vx=0.
            srex_vy=0.
            srim_vy=0.
            srex_tke=0.
            srim_tke=0.
            srex_trc=0.
            srim_trc=0.
            time=time+dt
            time_pr=time_pr+dt

! first compute the diffusion coefficients

             call cdtur(nzm,nz,ck,tke,dlk,cdz)

! compute the implicit and explicit terms of the equation for vx,vy and tke

             call building(nzm,nz,dz,pb,vl,vx,vy,cdragx,cdragy,cdragx1,cdragy1,cdragveg,cdragveg1,&
             cdragveg2,lambdap,wx,wy,bx,by,lad_in,srim_vx,srim_vy,srex_tke,srim_tke,lpz)
             call tke_bougeault(nzm,nz,ceps,dz,vx,vy,tke,cdz,dls,sf, &                      
                                srim_tke,srex_tke,sh,td)
         !    write(*,*)'srex_vx',srex_vx

! add the pressure gradient - add the dispersive transport here.
             srex_vx=srex_vx+dpdx
             srex_vy=srex_vy+dpdy
             srex_trc(1)=emi/dz/vl(1)
             srex_trc(nz)=-emi/dz

! compute the vertical diffusion
            call diff(nzm,nz,1,1,dt,vx,cdz,srim_vx,srex_vx,sf,vl,dz,uw,duwdz)
            call diff(nzm,nz,1,1,dt,vy,cdz,srim_vy,srex_vy,sf,vl,dz,vw,dvwdz)

            call diff(nzm,nz,1,1,dt,tke,cdz,srim_tke,srex_tke,sf,vl,dz,wtke,dwtkedz)


            call diff(nzm,nz,1,1,dt,trc,cdz,srim_trc,srex_trc,sf,vl,dz,wtrc,dwtrcdz)

              if(time_pr.gt.prtime)then
               write(*,*)'time=',time, vx(nzc) !, wtke, dwtkedz
               time_pr=dt
               do iz=1,nz
                uwm=(uw(iz)+uw(iz+1))/2.
               enddo
              endif
           enddo

           write(*,*)'time=',time
!           write(001,2001)'ss,pb,vl,sf,lpz'  
            do iz=1,nz-1
              uwm=(uw(iz)+uw(iz+1))/2.
              wtrcm=(wtrc(iz)+wtrc(iz+1))/2.
              write(68,'(i3,7(2x,f15.8))')iz,lad_max,vx(iz)/utau_x,tke(iz)/(utau_x**2.),&
              uwm/(utau_x**2.),trc(iz),wtrcm/emi,cdragx(iz)
            enddo

             do iz=1,nz
               write(001,'(5(2x,f15.8))')ss(iz),pb(iz),vl(iz),sf(iz),lpz(iz)
             enddo

             do iz=1,nz
               write(002,'(5(2x,f15.8))')sh(iz),td(iz),srex_tke(iz),srim_tke(iz),dwtkedz(iz)
             enddo

             do iz=1,nz
               write(003,'(6(2x,f15.8))')srex_vx(iz),srim_vx(iz),duwdz(iz),srex_vy(iz),srim_vy(iz),dvwdz(iz)
             enddo


           stop
           end   

!-------------------------------------------------------------
           subroutine read_input(nzm,nz,z,dz,dt,time_max,ntime,prtime,utau_x,utau_y,&
dpdx,dpdy,pb,ss,wx,wy,bx,by,hmean,Hmax,vl,sf,lpz)          
           implicit none
           integer nzm
! flow variables
           real dpdx,dpdy ! external pressure gradient 
           real utau_x,utau_y ! external pressure gradient 
! building information
           real ss(nzm+1) ! ss(iz)=probability to have a building of height z(iz)
           real lpz(nzm)
           real pb(nzm+1) ! pb(iz)=probbaility to have a building taller or equal to z(iz)
           real wx,wy ! distance between buildings at street level in the x and y direction respectively
           real bx,by ! building dimension in the x and y direction respectively
           real hmean ! mean buiolding height
           real Hstd,Hmax ! standard deviation and maximum building height
! numerical parameters
           real dz ! vertical resolution
           integer nz ! number of vertical levels
           real z(nzm+1) ! height of the faces of the numerical grid
           real dt ! time step
           integer iz,jz ! loop indexes for vertical
           integer ntime ! total number of timesteps
           real prtime ! frequency of output
           real vl(nzm) ! fraction of air in each cell
           real sf(nzm+1) ! fraction of air at the interface between cells  
           real time_max            
! Local
           character*256 line
           real hgt,prb,sstot,lambdap
           
!
            open(unit=20,file='input_column.dat')
10          read(20,'(A256)',END=20) line

            if (index(line,'number of points (nz)').ne.0) then
             read(20,*) nz
             if(nz.gt.nzm)then
              write(*,*)'increase nzm to ',nz
              stop
             endif
            end if

            if (index(line,'vertical resolution (dz)').ne.0) then
             read(20,*) dz
            end if

            if (index(line,'pressure forcing (utau_x, utau_y)').ne.0) then
             read(20,*) utau_x,utau_y
            end if

            if (index(line,'building dimensions (bx,by)').ne.0) then
             read(20,*) bx,by
            end if

            if (index(line,'distance between buildings (wx,wy)').ne.0) then
             read(20,*) wx,wy
            end if

            if (index(line,'building height information (Hstd,Hmax)').ne.0) then
              read(20,*) Hstd,Hmax
              write(*,*)Hstd, Hmax
             end if

            
            if (index(line,'building heights and probabilities (must be an integer number of dz)').ne.0) then
              ss=0.
              pb=0. ! 16 1
              read(20,*)hgt,prb ! construct the correct ss and pb
            end if
            
           if (index(line,'time step (dt)').ne.0) then
             read(20,*) dt
            end if

           if (index(line,'total time of simulation (time_max)').ne.0) then
             read(20,*) time_max
            end if

            if (index(line,'frequency of output (prtime)').ne.0) then
             read(20,*) prtime
            end if

  go to 10          
 20   continue


open(unit=66,file='lpz.dat')
!READ(66,*) lpzi
do iz=1,nzm
READ(66,*) lpz(iz)
end do
! define the mesh

             do iz=1,nzm+1
              z(iz)=real(iz-1)*dz ! 0,1,2,3,4,5,6,7,8,9---
             enddo


! define probabilities - now read the profile directly from input
           !    do iz=1,nzm+1
           !      if(z(iz).eq.hgt)then
           !       ss(iz)=prb ! only ss(17) has value of 1 - but this ss is not involved in the actual calculation 
           !      endif
           !    enddo


open(unit=688,file='ss.dat')
!READ(66,*) lpzi
do iz=1,nzm
READ(688,*) ss(iz)
end do
             

              do iz=1,nzm+1
               sstot=0.
               do jz=iz,nzm+1
                sstot=sstot+ss(jz)
               enddo
               pb(iz)=sstot ! below 17, all 1 - could be used to construct lp(z) - more like lpz(iz)/lp(1)
             enddo 

! write(*,*) pb
! compute fraction of air for each grid cell
!             lambda_p=bx*by/((wx+bx)*(wy+by)) 

             sf(nzm+1)=1. ! matter?
! compute mean height 
             hmean=0.
             do iz=1,nz
              hmean=hmean+z(iz)*ss(iz)
             enddo


! pressure gradient
            dpdx=(utau_x**2.)/z(nz)
            dpdy=(utau_y**2.)/z(nz)
            ntime=time_max/dt


      write(30,*)' utau_x =',utau_x,' utau_y =',utau_y,' dpdx =',dpdx
      write(30,*)' Domain_height =',z(nz)

      return
      end
! April 2016 by NN: added bx by wx wy as the input of this function to avoid hard-coded input of bx and by
!-----------------------------------------------------------------
      subroutine drag_length(nzm,nz,z,bx,by,wx,wy,hmean,Hmax,lambdap,ceps,ck,cmu,cdragx,cdragy,dls,dlk,lpz)
      implicit none
! input
      integer nzm,nz,iz
      real z(nzm+1)
      real dls(nzm),dlk(nzm)      
      real hmean,aa,Hmax
      real ceps,ck,cmu,lambdap
! output
      real cdragx(nzm),cdragy(nzm),lpz(nzm)
!local
      real disp,zc
      real lambdaf_x,lambdaf_y,bx,by,wx,wy,zh
!-----------------------------------------------------------------
! May 2019 NN: added for calculating the 1) Cmu and 2) Ceps below and above the building height
! based on LES 
! Staggered data used so far
! the drag coefficent is also updated based on LES but is very similar to RANS
!-----------------------------------------------------------------
      real a1,a15,a2, d1, d15,d2 
      real cmu_can, cmu_above
!-----------------------------------------------------------------	 
! In the canopy, Cmu = max(0.05, -1.6*lp^2 + 0.75*lp + 0.022)
! for z/H<1, Leps/Ceps=a1*(zc-d1), and a1 derived from LES data 
      a1 =  4.0
! a2 is derived for z/H<1.5 from LES results:
	  !a15 (i.e constant at 1<z/H<1.5) is kept similar to a1
      a15 = 4.0
!     above canopy
      a2=amin1(5.,amax1(2.,1.3*lambdap**(-0.45)))
! derived from LES results
      cmu_can = amax1(0.05,-1.6*lambdap**2+0.75*lambdap+0.022) ! safe to use this as indicated by new LES results - JL2023
      !cmu_can = 0.1661*lambdap**(0.3606)
      cmu_above = 0.05
!-----------------------------------------------------------------  
!-----------------------------------------------------------------	 
! since normalized mean building height is 1.0, and normalized urban unit area is 1.0
      zh=hmean
      lambdaf_x=bx*zh/((bx+wx)*(by+wy))
      lambdaf_y=by*zh/((bx+wx)*(by+wy))
            write(30,*)'Lfx =',lambdaf_x
            write(30,*)'Lp =',lambdap
            write(30,*)'bx=',bx, ' wx=', wx
            write(30,*)'by=',by, ' wy=', wy

! compute the displacement height
!      lambda_p=bx*by/((wx+bx)*(wy+by))
! because hmean is used here we can simply use the lambda_p at ground level and it will work for any building height distribution pb; of course there is an assumption
! inherent in this that length scales will behave similarly for different levels of building height variability
      disp=hmean*(lambdap)**(0.15)
!      disp=hmean*(lambdap)**(0.13)

! Drag coefficient
! The 'do' and 'if' statements need to be reversed in order for the final model version (so that cdrag depends on lambdaP*pb at each level)
! ---------------May 2019 by Neg: Parameterization of drag modified based on the LES results updated with rho=1
      
! add the sectional drag here
write(*,*)'hmax=', Hmax
aa = 1/lpz(1)*(Hmax-hmean)/hmean*0.8

! JL2023 Applied variable cdeq here changing with sectional density
       do iz=1,nz
       if (lpz(iz).le.0.4) then   
        cdragx(iz)=-10.8*(lpz(iz))**(2)+13.3*(lpz(iz))
        !cdragy(iz)=cdragx(iz)
       else
        cdragx(iz)=3.77
        !cdragy(iz)=3.77
       endif
       if (z(iz).ge.16)then
       cdragx(iz) = cdragx(iz)*aa ! amplification factor
       endif
       enddo
!-26.66*lpz(1)


write(*,*) aa
!cdragx(1) = cdragx(1)*(max(1.,-26.66*lpz(1)+12.15))
cdragy=cdragx





!----------- Added by NN May 2019--- --------------------------
! ------------------length scale CkLk -----------------------------
! ------------------note that Ck is included in the parameterizatin ---------
! For Cmu calculations, the average value below the building height is varied with height, and constant above the building 
! Cmu (z>H)=0.05
do iz=1,nz
       zc=(z(iz)+z(iz+1))/2.
!  based on wpup + wtut 
        if(hmean.eq.0.) then
! this must be the case to match the parameterization when hmean>0 (i.e., as hmean -> 0)
! NOTE: dls includes the ceps 
         dls(iz)=a2*zc
         cmu=cmu_can
       else      
!       write(*,*)'here1',disp,hmean
       if((zc/hmean).le.1.) then
          dls(iz)=a1*(hmean-disp)
          cmu=cmu_can
          if(zc/hmean.gt.0.9) cmu=(cmu_can*(1.1-zc/hmean)+ &
                      cmu_above*(zc/hmean-0.9))/0.2
        elseif((zc/hmean).gt.1..and.(zc/hmean).le.1.5)then
         d15=(1.-a1/a15)*hmean+a1/a15*disp
         dls(iz)=a15*(zc-d15)       
         cmu=cmu_above
         if(zc/hmean.lt.1.1) cmu=(cmu_can*(1.1-zc/hmean)+ &
                      cmu_above*(zc/hmean-0.9))/0.2
          elseif((zc/hmean).gt.1.5)then
          d2=(1.-a15/a2)*1.5*hmean+a15/a2*d15
          dls(iz)=a2*(zc-d2)
          cmu=cmu_above
         endif
! Similarly: dlk inclused Ck 
         dlk(iz)=cmu*dls(iz)
        endif
!        write(126,*)'DRAG,LS',iz,cdrag(iz),dls(iz)
!       cdrag(iz)=cdrag(iz)/4.
        write(37,*) zc/hmean, dlk(iz), dls(iz), cmu
enddo
! --------------------------------------------------------------------
      return
      end

!----------------------------------------
! ===6================================================================72
! ===6================================================================72

      subroutine cdtur(nzm,nz,ck,tke,dlk,cdz)                                  


      implicit none

! Input
! -----
      integer nzm                              ! maximum number of vertical levels
      integer nz                               ! number of vertical levels
      real ck                                  ! von Karman constant
      real tke(nzm)                             ! turbulent kinetic energy
      real dlk(nzm)                             ! length scale

! Output
! ------
      real cdz(nzm+1)                            ! diffusion coefficient

! Local
! -----
      integer iz
      real tke_m
      real dlk_m

! ----------------------------------------------------------------------

       cdz(1)=0.

!       do iz=2,nz-1
       do iz=2,nz
        tke_m=(tke(iz-1)+tke(iz))/2.
        dlk_m=(dlk(iz-1)+dlk(iz))/2.
! ----------Modified by NN Jan 2017 to parameterize CkLk instead of Lk alone
!        cdz(iz)=ck*dlk_m*sqrt(tke_m)
        cdz(iz)=dlk_m*sqrt(tke_m)
       enddo
       cdz(nz+1)=cdz(nz)

       return
       end  

! ===6================================================================72

      subroutine building(nzm,nz,dz,pb,vl,vx,vy,cdragx,cdragy,cdragx1,cdragy1,cdragveg,cdragveg1,&
              cdragveg2,lambdap,wx,wy,bx,by,lad,srim_vx,srim_vy,srex_tke,srim_tke,lpz)
      implicit none
! input      
      integer nzm
      integer nz,iz
      real dz,pb(nzm+1),vl(nzm),lpz(nzm)
      real cdragx(nzm),cdragy(nzm),wx,wy,bx,by
      real vx(nzm),vy(nzm),lambdap
      real cdragx1(nzm),cdragy1(nzm),cdragveg,cdragveg1,cdragveg2,lad(nzm)
! output      
      real srim_vx(nzm),srim_vy(nzm),srex_tke(nzm),srim_tke(nzm)
! local
      real lfx,lfy,wx_tmp,bx_tmp

      do iz=1,nz
! --------------------
!      Neg May 2017: I don't understand why this consideration is needed
! assuming square buildings:
       by=bx
!----------------------
       bx_tmp=sqrt(lambdap*pb(iz+1))

!       if(bx_tmp.eq.0.) then
!        write(6,*)'iz,lp,pb',iz,lambdap,pb(iz+1)
!       stop
!       endif
       wx_tmp=1.-bx_tmp
! --------------------
!      NN May 2017: this calculation replaces the value of wx and wy from the user input, therefore
!                    it is not accurate to use nscen~=1. Recommand using different symbol 
       wx=wx_tmp*bx/max(bx_tmp,1.e-9)
       wy=wx

       lfx=dz*by/((wx+bx)*(wy+by))*pb(iz) ! lfx(iz)
       lfy=dz*bx/((wx+bx)*(wy+by))*pb(iz)


       srim_vx(iz)=-lfx/vl(iz)/dz*cdragx(iz)*abs(vx(iz))
       srim_vy(iz)=-lfy/vl(iz)/dz*cdragy(iz)*abs(vy(iz))
!       srim_vx(iz)=-lfx/vl(iz)/dz*cdragx(iz)*abs(vx(iz))
!       srim_vy(iz)=-lfy/vl(iz)/dz*cdragy(iz)*abs(vy(iz))
! not sure it is like this for tke, but for wind orthotogonal to the face of the cube, 
! vy=0.
       srex_tke(iz)=cdragx1(iz)*(lfx/vl(iz)/dz*(abs(vx(iz))**3.))+&
                    cdragy1(iz)*(lfy/vl(iz)/dz*(abs(vy(iz))**3.))
!      srex_tke(iz)=cdragx1(iz)*(lfx/vl(iz)/dz*(abs(vx(iz))**3.))+cdragy1(iz)*(lfy/vl(iz)/dz*(abs(vy(iz))**3.))

! The coefficient 6.5 comes from Jose Luis' Raupach comparision, using parameters from Dalpe and Masson
       srim_tke(iz)=0 ! no vegetation effects considered

      enddo

      return
      end
      
!------------------------------------------------     

      subroutine tke_bougeault (nzm,nz,ceps,dz,vx,vy, &
                                tke,cdz,dls,sf, &                       ! Input
                                srim_tke,srex_tke,sh,td)                            ! Output


! ----------------------------------------------------------------------
!   Calculation of the sources (shear) and the dissipation
!    terms for the TKE equation.
! ----------------------------------------------------------------------

      implicit none

! Input
! -----
      integer nz,nzm                               ! number of vertical levels
    
      real ceps
      real dz                                  ! levels size [m]
      real vx(nzm)                              ! wind velocity
      real vy(nzm)                              ! wind velocity     
      real tke(nzm)                             ! turbulent kinetic energy
      real cdz(nzm+1)                           ! turbulent diffusion coefficient
      real dls(nzm)                             ! lrngth scale leps
      real sf(nzm+1)                            ! ?????

! Ouput
! -----
      real srim_tke(nzm)                           ! inplicit term in the tke equation
      real srex_tke(nzm)                           ! explicit term in the tke equation

! Local
! -----
      integer iz
      real sh(nzm)                              ! shear turbulent kinetic energy source
      real td(nz)                              ! dissipation

! ----------------------------------------------------------------------

      call shear (nzm,nz,dz,vx,vy,cdz, &                               ! Input
                  sh)                                              ! Ouput

      do iz=1,nz

! td is epsilon, and sh is shear production!
       if (dls(iz).ne.0.) then
           ! ----------Modified by Neg Jan 2017 to parameterize CkLk instead of Lk alone
!        td(iz)=-ceps*sqrt(tke(iz))/dls(iz)
        td(iz)=-sqrt(tke(iz))/dls(iz)
                else
        td(iz)=0.
       end if ! dls
       sh(iz)=sh(iz)*sf(iz)
! VEGETATION (to account elsewhere for the short-circuit):
       srim_tke(iz)=srim_tke(iz)+td(iz)
!       srim_tke(iz)=td(iz)
       srex_tke(iz)=srex_tke(iz)+sh(iz)
      end do ! iz
      return
      end  !

! closing output files
!close(30)
!close(68)

! ===6================================================================72
! ===6================================================================72

      subroutine shear(nzm,nz,dz,vx,vy,cdz, &                               ! Input
                       sh)                                              ! Ouput



! ----------------------------------------------------------------------
!     Calculation of the shear source for the TKE equation.
! ----------------------------------------------------------------------

      implicit none

! Input
! -----
      integer nzm,nz                               ! number of vertical levels
      real dz                              ! levels size [m]
      real vx(nzm)                              ! wind velocity
      real vy(nzm)                              ! wind velocity
      real cdz(nzm+1)                           ! turbulent diffusion coefficient

! Ouput
! -----
      real sh(nzm)                              ! shear turbulent kinetic energy source

! Local
! -----
      integer iz
      real dudz1
      real dvdz1
      real dudz2
      real dvdz2
      real cdm
      real dumdz
      real cdmmin
      parameter (cdmmin=0.01)

! ----------------------------------------------------------------------

      sh(1)=0.

      do iz=2,nz-1

        dudz1=(vx(iz)-vx(iz-1))/dz
        dvdz1=(vy(iz)-vy(iz-1))/dz
        dudz2=(vx(iz+1)-vx(iz))/dz
        dvdz2=(vy(iz+1)-vy(iz))/dz

        cdm=max(0.5*(cdz(iz)+cdz(iz+1)),cdmmin)

        dumdz=0.5*((dudz1**2.+dvdz1**2)+(dudz2**2.+dvdz2**2))

        sh(iz)=cdm*dumdz
  
      enddo  ! iz

      sh(nz)=0.

      return ! shear
      end

! ===6================================================================72 
! ===6=8===============================================================72

       subroutine diff(nzm,nz,iz1,izf,dt,co,cd,aa,bb,sf,vl,dz,fc,df)

!     +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!     +           Subroutine prepared by A.Martilli                     +
!     +        Ecole Polytechnique Federale de Lausanne                 +
!     +   DGR - IGE - Laboratoire de Pollution de l'Air et des Sols     +
!     +            tel.: (021)-693-61-60                                +
!     +            Email: alberto.martilli@dgr.epfl.ch                  + 
!     +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

!------------------------------------------------------------------------
!           Calculation of the diffusion in 1D        
!------------------------------------------------------------------------
!  - Input:
!       nz    : number of points
!       iz1   : first calculated point
!       co    : concentration of the variable of interest
!       dz    : vertical levels
!       cd    : diffusion coefficients
!       dtext : external time step
!       itest : if itest eq 1 then update co, else store in a flux array
!  - Output:
!       co :concentration of the variable of interest

!  - Internal:
!       cddz  : constant terms in the equations 
!       dt    : diffusion time step
!       nt    : number of the diffusion time steps
!       cstab : ratio of the stability condition for the time step
!---------------------------------------------------------------------

         implicit none
                
         integer nz,nzm,iz,iz1,izf
         real co(nzm),cd(nzm+1),dz,dt,dzv

         real cddz(nzm+2),fc(nzm+1),df(nzm)
         real a(nzm,3),c(nzm)
         real sf(nzm+1),vl(nzm)
         real aa(nzm),bb(nzm)
        
! Compute cddz=2*cd/dz  
        
        cddz(1)=sf(1)*cd(1)/dz ! ground boundary condition
        do iz=2,nz
         cddz(iz)=2.*sf(iz)*cd(iz)/(2.*dz)
        enddo
        if(izf.gt.0)then
         cddz(nz+1)=sf(nz+1)*cd(nz+1)/dz
        else
         cddz(nz+1)=0.
        endif
         do iz=1,iz1-1
          a(iz,1)=0.
          a(iz,2)=1.
          a(iz,3)=0.
          c(iz)=co(iz)
         enddo
          
          do iz=iz1,nz-izf
           dzv=vl(iz)*dz
           a(iz,1)=-cddz(iz)*dt/dzv         
           a(iz,2)=1+dt*(cddz(iz)+cddz(iz+1))/dzv-aa(iz)*dt
           a(iz,3)=-cddz(iz+1)*dt/dzv            
           c(iz)=co(iz)+bb(iz)*dt                     
          enddo

          if(izf.eq.1)then
           dzv=vl(nz)*dz
           a(nz,1)=-cddz(nz)*dt/dzv        
           a(nz,2)=1+dt*(cddz(nz))/dzv-aa(nz)*dt
           a(nz,3)=0.            
           c(nz)=co(nz)+bb(nz)*dt   
          else
           do iz=nz-izf+1,nz
            a(iz,1)=0.
            a(iz,2)=1.
            a(iz,3)=0.
            c(iz)=co(iz)
           enddo
          endif

          call invert (nzm,nz,a,c,co)
                  
          do iz=1,iz1 
           fc(iz)=0.
          enddo
          
          do iz=iz1+1,nz 
           fc(iz)=-(cddz(iz)*(co(iz)-co(iz-1)))
          enddo
        
          do iz=1,iz1
           df(iz)=0.
          enddo
          
          do iz=iz1+1,nz-izf
           dzv=vl(iz)*dz
           if(iz.lt.nz)then
            df(iz)=(co(iz-1)*cddz(iz)&
                 -co(iz)*(cddz(iz)+cddz(iz+1))&
                 +co(iz+1)*cddz(iz+1))/dzv
           else
            df(iz)=(co(iz-1)*cddz(iz)&
                 -co(iz)*(cddz(iz)+cddz(iz+1)))/dzv
           endif
          enddo
          
          do iz=nz-izf,nz 
           df(iz)=0.
          enddo
                                        
       return
       end
!----------------------------------------------------------------------------

       subroutine invert(nzm,nn,a,c,x)
       implicit none
       
!ccccccccccccccccccccccccccccccc       
! Aim: INversion and resolution of a tridiagonal matrix
!          A X = C
! Input:
!  a(*,1) lower diagonal (Ai,i-1)
!  a(*,2) principal diagonal (Ai,i)
!  a(*,3) upper diagonal (Ai,i+1)
!  c      
! Output
!  x     results
!ccccccccccccccccccccccccccccccc 
       integer nzm,nn,in
       real a(nzm,3),c(nzm),x(nzm)                       
        
        do in=nn-1,1,-1                 
         c(in)=c(in)-a(in,3)*c(in+1)/a(in+1,2)
         a(in,2)=a(in,2)-a(in,3)*a(in+1,1)/a(in+1,2)
        enddo
        
        do in=2,nn        
         c(in)=c(in)-a(in,1)*c(in-1)/a(in-1,2)
        enddo
        
        do in=1,nn
         x(in)=c(in)/a(in,2)
        enddo

        return
       end
