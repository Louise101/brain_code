module inttau2

   implicit none

   private
   public :: tauint1, find_taumax

CONTAINS

    subroutine tauint1(xcell,ycell,zcell,tflag,iseed,delta)
    !optical depth integration subroutine
    !
    !
        use constants,   only : xmax, ymax, zmax,nxg,nyg,nzg
        use photon_vars, only : xp, yp, zp
        use iarray,      only : jmean, rhokap, si_step, jme

        use vector_class

        implicit none

        real,    intent(IN)    :: delta
        integer, intent(INOUT) :: xcell, ycell, zcell, iseed
        logical, intent(INOUT) :: tflag

        real                   :: tau, taurun, taucell, xcur, ycur, zcur, d, dcell, ran2
        integer                :: celli, cellj, cellk
        logical                :: dir(3)

        xcur = xp + xmax
        ycur = yp + ymax
        zcur = zp + zmax

        celli = xcell
        cellj = ycell
        cellk = zcell

        taurun = 0.
        d = 0.
        dir = (/.FALSE., .FALSE., .FALSE./)

        !sample optical distance
        tau = -log(ran2(iseed))
        do
            dir = (/.FALSE., .FALSE., .FALSE./)
            !get distance to nearest wall in direction dir
            dcell = wall_dist(celli, cellj, cellk, xcur, ycur, zcur, dir)

            !calculate optical distnace to cell wall
            taucell = dcell * rhokap(celli,cellj,cellk)

            if(taurun + taucell < tau)then!still some tau to move
                taurun = taurun + taucell
                d = d + dcell

                jmean(celli, cellj, cellk) = jmean(celli, cellj, cellk) + dcell ! record fluence

                si_step(celli,cellj,cellk) = si_step(celli, cellj, cellk) + dcell !record path lengths for current step

                call update_pos(xcur, ycur, zcur, celli, cellj, cellk, dcell, .TRUE., dir, delta, tflag, iseed, &
                                tau, taurun)
            else!moved full distance

                dcell = (tau - taurun) / rhokap(celli,cellj,cellk)
                d = d + dcell

                jmean(celli, cellj, cellk) = jmean(celli, cellj, cellk) + dcell !record fluence

                si_step(celli,cellj,cellk) = si_step(celli, cellj, cellk) + dcell !record path lengths for current step

                call update_pos(xcur, ycur, zcur, celli, cellj, cellk, dcell, .FALSE., dir, delta, tflag, iseed, &
                                tau, taurun)
                exit
            end if
            if(celli == -1 .or. cellj == -1 .or. cellk == -1)then
                !if(celli == -1 .or. cellj == -1)then
                !    call repeat_bounds(celli, cellj, xcur, ycur, xmax, ymax, nxg, nyg, delta)
                !    tflag = .false.
                !    if(celli == -1 .or. cellj == -1 .or. tflag)then
                !       print*,'error',celli,cellj,tflag
                !    end if
                !else
                    tflag = .true.
                    exit
                end if
          !  end if
        end do

        xp = xcur - xmax
        yp = ycur - ymax
        zp = zcur - zmax
        xcell = celli
        ycell = cellj
        zcell = cellk

    end subroutine tauint1





    subroutine find_taumax(xcell,ycell,zcell,tau_max,iseed,tflag,dirx,diry,dirz)

      use photon_vars, only:xp,yp,zp
      use constants,   only : xmax, ymax, zmax,nxg,nyg,nzg
      use iarray, only: rhokap

      implicit none

      real, intent(OUT):: tau_max
      real, intent(IN)::dirx,diry,dirz
      integer, intent(IN):: xcell, ycell, zcell
      logical, intent(INOUT):: tflag
      integer, intent(INOUT):: iseed

      real :: xcur, ycur, zcur, dsx, dsy, dsz, d_max, delta, dis
      real :: dcell, taucell, taurun, tau, ran2
      integer :: celli,cellj,cellk
      logical :: dir(3)

      xcur=xp+xmax
      ycur=yp+ymax
      zcur=zp+zmax

      celli=xcell
      cellj=ycell
      cellk=zcell


      delta = 1.e-8*(2.*zmax/nzg)
      dis=0.
      dcell=0.
      taucell=0.
      taurun=0.
      dir = (/.FALSE., .FALSE., .FALSE./)

      if(dirx .gt. 0.) then
        dsx=(2.*xmax-xcur)/dirx
      elseif ( dirx .lt. 0. ) then
        dsx=-xcur/dirx
      elseif ( dirx .eq. 0. ) then
        dsx=1.e2*xmax
      endif

      if(diry .gt. 0.) then
        dsy=(2.*ymax-ycur)/diry
      elseif ( diry .lt. 0. ) then
        dsy=-ycur/diry
      elseif ( diry .eq. 0. ) then
        dsy=1.e2*ymax
      endif

      if(dirz .gt. 0.) then
        dsz=(2.*zmax-zcur)/dirz
      elseif ( dirz .lt. 0. ) then
        dsz=-zcur/dirz
      elseif ( dirz .eq. 0. ) then
        dsz=1.e2*zmax
      endif

      d_max = amin1(dsx,dsy,dsz)

      if (d_max .lt. delta) then
        tau_max = 0.
        return
      endif

      do while(dis .lt. (0.999*d_max) .and. celli/=-1 .and. cellj/=-1 .and. cellk/=-1)
      !  print*, '1',dis,dcell, d_max
      !  tau = -log(ran2(iseed)) !pick random optical distance - maybe doesnt have to be random . .
      !print*, celli,cellj,cellk,xcur,ycur,zcur
    !  print*, 'this wall', celli
        dcell = wall_dist(celli, cellj, cellk, xcur, ycur, zcur, dir)
      !  print*, dcell, 'dcell'
        !print*, dcell, dis
      !  print*, '2',dis, dcell
        taucell=dcell*rhokap(celli,cellj,cellk)

      !  if(taurun + taucell < tau)then!still some tau to move
            taurun = taurun + taucell
            !print*, taucell, taurun
            dis = dis + dcell
            !print*, '3',dis, dcell
            call update_pos_taumax(xcur, ycur, zcur, celli, cellj, cellk, dcell, .TRUE., dir, delta, tflag, iseed, &
                            tau, taurun)



            !  print*, 'inside', taurun
      !      print*, '4',dis, dcell
      !  else!moved full distance

      !      dcell = (tau - taurun) / rhokap(celli,cellj,cellk)
      !      dis = dis + dcell
            !print*, '5',dis, dcell

      !      call update_pos(xcur, ycur, zcur, celli, cellj, cellk, dcell, .FALSE., dir, delta, tflag, iseed, &
      !                      tau, taurun)
      !      print*, '6',dis, dcell
            !exit
      !  end if


      end do
    !  print*, dis, d_max


      tau_max=taurun


    end subroutine find_taumax

!************************ bin photons according to position and direction *********************************************


    subroutine repeat_bounds(cella, cellb, acur, bcur, amax, bmax, nag, nbg, delta)
    !   if photon leaves grid in a direction a or b, then photon is transported to otherside and continues being simulated
    !
    !
        implicit none

        real,    intent(INOUT) :: acur, bcur
        real,    intent(IN)    :: delta, amax, bmax
        integer, intent(IN)    :: nag, nbg
        integer, intent(INOUT) :: cella, cellb

        if(cella == -1)then
            if(acur < delta)then
                acur = 2.*amax  - delta
                cella = nag
            elseif(acur > 2. * amax - delta)then
                acur = delta
                cella = 1
            else
                print*,'Error in Repeat_bounds...'
                call exit(0)
            end if
        end if
        if(cellb == -1)then
            if(bcur < delta)then
                bcur = 2.*bmax-delta
                cellb = nbg
            elseif(bcur > 2.*bmax-delta)then
                bcur = delta
                cellb = 1
            else
                print*,'Error in Repeat_bounds...'
                call exit(0)
            end if
        end if
    end subroutine repeat_bounds


    real function wall_dist(celli, cellj, cellk, xcur, ycur, zcur, dir)
    !funtion that returns distant to nearest wall and which wall that is (x,y or z)
    !
    !
        use iarray,      only : xface, yface, zface
        use photon_vars, only : nxp, nyp, nzp

        implicit none

        real,    intent(INOUT) :: xcur, ycur, zcur
        logical, intent(INOUT) :: dir(:)
        integer, intent(INOUT) :: celli, cellj, cellk
        real                  :: dx, dy, dz


        if(nxp > 0.)then
            dx = (xface(celli+1) - xcur)/nxp
        elseif(nxp < 0.)then
            dx = (xface(celli) - xcur)/nxp
        elseif(nxp == 0.)then
            dx = 100000.
        end if

        if(nyp > 0.)then
            dy = (yface(cellj+1) - ycur)/nyp
        elseif(nyp < 0.)then
            dy = (yface(cellj) - ycur)/nyp
        elseif(nyp == 0.)then
            dy = 100000.
        end if

        if(nzp > 0.)then
            dz = (zface(cellk+1) - zcur)/nzp
        elseif(nzp < 0.)then
            dz = (zface(cellk) - zcur)/nzp
        elseif(nzp == 0.)then
            dz = 100000.
        end if



        wall_dist = min(dx, dy, dz)
        if(wall_dist < 0.)print'(A,7F9.5)','dcell < 0.0 warning! ',wall_dist,dx,dy,dz,nxp,nyp,nzp
        if(wall_dist == dx)dir=(/.TRUE., .FALSE., .FALSE./)
        if(wall_dist == dy)dir=(/.FALSE., .TRUE., .FALSE./)
        if(wall_dist == dz)dir=(/.FALSE., .FALSE., .TRUE./)
        if(.not.dir(1) .and. .not.dir(2) .and. .not.dir(3))print*,'Error in dir flag'

   end function wall_dist



    subroutine update_pos(xcur, ycur, zcur, celli, cellj, cellk, dcell, wall_flag, dir, delta, tflag, iseed, &
                          tau, taurun)
    !routine that upates postions of photon and calls fresnel routines if photon leaves current voxel
    !
    !
        use photon_vars, only : nxp, nyp, nzp, phi, cost, sint, cosp, sinp
        use iarray,      only : xface, yface, zface, refrac
        use constants,   only : nzg
        use vector_class

        implicit none

      real,    intent(INOUT) :: xcur, ycur, zcur, tau, taurun
      real,    intent(IN)    :: dcell, delta
      integer, intent(INOUT) :: celli, cellj, cellk, iseed
      logical, intent(IN)    :: wall_flag, dir(:)
      logical, intent(INOUT) :: tflag

      type(vector) :: norm, incd
      real         :: n1, n2, ran2
      integer      :: iold, jold, kold
      logical      :: rflag

      iold = celli
      jold = cellj
      kold = cellk

      rflag = .false.

      n1 = refrac(celli,cellj,cellk)

      if(wall_flag)then ! hits voxel wall so move delta into next voxel

         if(dir(1))then
            if(nxp > 0.)then
               xcur = xface(celli+1) + delta
            elseif(nxp < 0.)then
               xcur = xface(celli) - delta
            else
               print*,'Error in x dir in update_pos', dir, nxp, nyp, nzp
               stop 0
            end if
            ycur = ycur + nyp*dcell
            zcur = zcur + nzp*dcell
         elseif(dir(2))then
            xcur = xcur + nxp*dcell
            if(nyp > 0.)then
                ycur = yface(cellj+1) + delta
            elseif(nyp < 0.)then
                ycur = yface(cellj) - delta
            else
                print*,'Error in y dir in update_pos', dir, nxp, nyp, nzp
                stop 0
            end if
            zcur = zcur + nzp*dcell
         elseif(dir(3))then
            xcur = xcur + nxp*dcell
            ycur = ycur + nyp*dcell
            if(nzp > 0.)then
               zcur = zface(cellk+1) + delta
            elseif(nzp < 0.)then
               zcur = zface(cellk) - delta
            else
               print*,'Error in z dir in update_pos', dir, nxp, nyp, nzp
               stop 0
            end if
         else
            print*,'Error in update_pos...',dir
            stop 0
         end if
      else

        xcur = xcur + nxp*dcell
        ycur = ycur + nyp*dcell
        zcur = zcur + nzp*dcell

      end if
   ! if(cellk == 400) print*,cellk,n1,n2,nzp,kold



    if(wall_flag)then!do fresnel calculation
        call update_voxels(xcur, ycur, zcur, celli, cellj, cellk)
        if(celli == -1 .or. cellj == -1 .or. cellk == -1)then
            ! if(cellk ==-1)print*,kold,zcur
            tflag = .true.
            return
        end if
        n2 = refrac(celli,cellj,cellk)
    end if

      if(wall_flag)then
        if(n1 /= n2)then
            incd = vector(nxp, nyp, nzp)
            incd = incd%magnitude()
            if(iold /= celli)then                           ! x-dir

                norm = vector(1., 0., 0.)
                call reflect_refract(incd, norm, n1, n2, iseed, rflag)
                if(rflag)then
                    celli = iold
                    if(nxp > 0.)then
                        xcur = xface(celli+1) - delta
                    elseif(nxp < 0.)then
                        xcur = xface(celli) + delta
                    end if
                end if
            elseif(jold /= cellj)then                       ! y-dir

                norm = vector(0., 1., 0.)
                call reflect_refract(incd, norm, n1, n2, iseed, rflag)
                if(rflag)then
                    cellj = jold
                    if(nyp > 0.)then
                        ycur = yface(cellj+1) - delta
                    elseif(nyp < 0.)then
                        ycur = yface(cellj) + delta
                    end if
                end if
            elseif(kold /= cellk)then                       ! z-dir
                norm = vector(0., 0., 1.)
                call reflect_refract(incd, norm, n1, n2, iseed, rflag)
                if(rflag)then
                    cellk = kold
                    if(nzp > 0.)then
                        zcur = zface(cellk+1) - delta
                    elseif(nzp < 0.)then
                        zcur = zface(cellk) + delta
                    end if
                elseif(cellk == nzg + 1)then
                    cellk = -1
                    tflag = .true.
                end if
            else
                print*,'Error in reflect/refract in update_pos!'
                stop 0
            end if
                nxp = incd%x
                nyp = incd%y
                nzp = incd%z

                phi = atan2(nyp, nxp)
                sinp = sin(phi)
                cosp = cos(phi)

                cost = nzp
                sint = sqrt(1.-cost*cost)

                taurun = 0.
                tau = -log(ran2(iseed))
        end if
    end if
! end if
    end subroutine update_pos

    subroutine update_pos_taumax(xcur, ycur, zcur, celli, cellj, cellk, dcell, wall_flag, dir, delta, tflag, iseed, &
                          tau, taurun)
    !routine that upates postions of photon and calls fresnel routines if photon leaves current voxel
    !
    !
        use photon_vars, only : nxp, nyp, nzp, phi, cost, sint, cosp, sinp
        use iarray,      only : xface, yface, zface, refrac
        use constants,   only : nzg
        use vector_class

        implicit none

      real,    intent(INOUT) :: xcur, ycur, zcur, tau, taurun
      real,    intent(IN)    :: dcell, delta
      integer, intent(INOUT) :: celli, cellj, cellk, iseed
      logical, intent(IN)    :: wall_flag, dir(:)
      logical, intent(INOUT) :: tflag

      type(vector) :: norm, incd
      real         :: n1, n2, ran2
      integer      :: iold, jold, kold
      logical      :: rflag

      iold = celli
      jold = cellj
      kold = cellk

      rflag = .false.

      n1 = refrac(celli,cellj,cellk)

      if(wall_flag)then ! hits voxel wall so move delta into next voxel

         if(dir(1))then
            if(nxp > 0.)then
               xcur = xface(celli+1) + delta
            elseif(nxp < 0.)then
               xcur = xface(celli) - delta
            else
               print*,'Error in x dir in update_pos', dir, nxp, nyp, nzp
               stop 0
            end if
            ycur = ycur + nyp*dcell
            zcur = zcur + nzp*dcell
         elseif(dir(2))then
            xcur = xcur + nxp*dcell
            if(nyp > 0.)then
                ycur = yface(cellj+1) + delta
            elseif(nyp < 0.)then
                ycur = yface(cellj) - delta
            else
                print*,'Error in y dir in update_pos', dir, nxp, nyp, nzp
                stop 0
            end if
            zcur = zcur + nzp*dcell
         elseif(dir(3))then
            xcur = xcur + nxp*dcell
            ycur = ycur + nyp*dcell
            if(nzp > 0.)then
               zcur = zface(cellk+1) + delta
            elseif(nzp < 0.)then
               zcur = zface(cellk) - delta
            else
               print*,'Error in z dir in update_pos', dir, nxp, nyp, nzp
               stop 0
            end if
         else
            print*,'Error in update_pos...',dir
            stop 0
         end if
      else

        xcur = xcur + nxp*dcell
        ycur = ycur + nyp*dcell
        zcur = zcur + nzp*dcell

      end if
   ! if(cellk == 400) print*,cellk,n1,n2,nzp,kold



    if(wall_flag)then!do fresnel calculation
        call update_voxels(xcur, ycur, zcur, celli, cellj, cellk)
        if(celli == -1 .or. cellj == -1 .or. cellk == -1)then
            ! if(cellk ==-1)print*,kold,zcur
            tflag = .true.
            return
        end if
        n2 = refrac(celli,cellj,cellk)
    end if

      if(wall_flag)then
        if(n1 /= n2)then
            incd = vector(nxp, nyp, nzp)
            incd = incd%magnitude()
            if(iold /= celli)then                           ! x-dir

                norm = vector(1., 0., 0.)
                call reflect_refract(incd, norm, n1, n2, iseed, rflag)
                if(rflag)then
                    celli = iold
                    if(nxp > 0.)then
                        xcur = xface(celli+1) - delta
                    elseif(nxp < 0.)then
                        xcur = xface(celli) + delta
                    end if
                end if
            elseif(jold /= cellj)then                       ! y-dir

                norm = vector(0., 1., 0.)
                call reflect_refract(incd, norm, n1, n2, iseed, rflag)
                if(rflag)then
                    cellj = jold
                    if(nyp > 0.)then
                        ycur = yface(cellj+1) - delta
                    elseif(nyp < 0.)then
                        ycur = yface(cellj) + delta
                    end if
                end if
            elseif(kold /= cellk)then                       ! z-dir
                norm = vector(0., 0., 1.)
                call reflect_refract(incd, norm, n1, n2, iseed, rflag)
                if(rflag)then
                    cellk = kold
                    if(nzp > 0.)then
                        zcur = zface(cellk+1) - delta
                    elseif(nzp < 0.)then
                        zcur = zface(cellk) + delta
                    end if
                elseif(cellk == nzg + 1)then
                    cellk = -1
                    tflag = .true.
                end if
            else
                print*,'Error in reflect/refract in update_pos!'
                stop 0
            end if
                nxp = incd%x
                nyp = incd%y
                nzp = incd%z

                phi = atan2(nyp, nxp)
                sinp = sin(phi)
                cosp = cos(phi)

                cost = nzp
                sint = sqrt(1.-cost*cost)

                !taurun = 0.
                tau = -log(ran2(iseed))
        end if
    end if
! end if
end subroutine update_pos_taumax




    subroutine update_voxels(xcur, ycur, zcur, celli, cellj, cellk)
    !updates the current voxel based upon position
    !
    !
        use iarray,    only : xface, yface, zface

        implicit none

        real,    intent(IN)    :: xcur, ycur, zcur
        integer, intent(INOUT) :: celli, cellj, cellk

        celli = find(xcur, xface)
        cellj = find(ycur, yface)
        cellk = find(zcur, zface)

    end subroutine update_voxels


    integer function find(val, a)
    !searchs for bracketing indicies for a value val in an array a
    !
    !
        implicit none

        real, intent(IN) :: val, a(:)
        integer          :: n, lo, mid, hi

        n = size(a)
        lo = 0
        hi = n + 1

        if (val == a(1)) then
            find = 1
        else if (val == a(n)) then
            find = n-1
        else if((val > a(n)) .or. (val < a(1))) then
            find = -1
        else
            do
                if (hi-lo <= 1) exit
                mid = (hi+lo)/2
                if (val >= a(mid)) then
                    lo = mid
                else
                    hi = mid
                end if
            end do
            find = lo
        end if
    end function find


    subroutine reflect_refract(I, N, n1, n2, iseed, rflag)

        use vector_class

        implicit none

        type(vector), intent(INOUT) :: I
        type(vector), intent(INOUT) :: N
        real,         intent(IN)    :: n1, n2
        integer,      intent(INOUT) :: iseed
        logical,      intent(OUT)   :: rflag

        real :: ran2

        rflag = .FALSE.

        if(ran2(iseed) <= fresnel(I, N, n1, n2))then
            call reflect(I, N)
            rflag = .true.
        else
            call refract(I, N, n1/n2)
        end if

    end subroutine reflect_refract


    subroutine reflect(I, N)
    !   get vector of reflected photon
    !
    !
        use vector_class

        implicit none

        type(vector), intent(INOUT) :: I
        type(vector), intent(IN)    :: N

        type(vector) :: R

        R = I - 2. * (N .dot. I) * N
        I = R

    end subroutine reflect


    subroutine refract(I, N, eta)
    !   get vector of refracted photon
    !
    !
        use vector_class

        implicit none

        type(vector), intent(INOUT) :: I
        type(vector), intent(IN)    :: N
        real,         intent(IN)    :: eta

        type(vector) :: T, Ntmp

        real :: c1, c2

        Ntmp = N

        c1 = (Ntmp .dot. I)
        if(c1 < 0.)then
            c1 = -c1
        else
            Ntmp = (-1.) * N
        end if
        c2 = sqrt(1. - (eta)**2 * (1.-c1**2))

        T = eta*I + (eta * c1 - c2) * Ntmp

        I = T

    end subroutine refract


    function fresnel(I, N, n1, n2) result (tir)
    !   calculates the fresnel coefficents
    !
    !
        use vector_class
        use ieee_arithmetic, only : ieee_is_nan

        implicit none

        real, intent(IN)         :: n1, n2
        type(vector), intent(IN) :: I, N

        real             ::  costt, sintt, sint2, cost2, tir, f1, f2

        costt = abs(I .dot. N)

        sintt = sqrt(1. - costt * costt)
        sint2 = n1/n2 * sintt
        if(sint2 > 1.)then
            tir = 1.0
            return
        elseif(costt == 1.)then
            tir = 0.
            return
        else
            sint2 = (n1/n2)*sintt
            cost2 = sqrt(1. - sint2 * sint2)
            f1 = abs((n1*costt - n2*cost2) / (n1*costt + n2*cost2))**2
            f2 = abs((n1*cost2 - n2*costt) / (n1*cost2 + n2*costt))**2

            tir = 0.5 * (f1 + f2)
        if(ieee_is_nan(tir) .or. tir > 1. .or. tir < 0.)print*,'TIR: ', tir, f1, f2, costt,sintt,cost2,sint2
            return
        end if
    end function fresnel
end module inttau2
